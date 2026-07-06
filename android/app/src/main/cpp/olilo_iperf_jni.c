#include <android/log.h>
#include <jni.h>
#include <pthread.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

#include "iperf.h"
#include "iperf_api.h"

#define TAG "OliloIperfJNI"
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, TAG, __VA_ARGS__)

static struct iperf_test *global_test = NULL;
static pthread_t reader_thread;
static volatile bool stop_requested = false;

struct CallbackArgs {
    JavaVM *jvm;
    jobject callback_global;
    int pipe_fd;
};

static void emit_callback_string(JNIEnv *env, jobject callback, jmethodID method, const char *message) {
    jstring value = (*env)->NewStringUTF(env, message);
    (*env)->CallVoidMethod(env, callback, method, value);
    (*env)->DeleteLocalRef(env, value);
}

static void *reader_thread_func(void *args_ptr) {
    struct CallbackArgs *args = (struct CallbackArgs *) args_ptr;
    JNIEnv *env = NULL;
    (*args->jvm)->AttachCurrentThread(args->jvm, (void **) &env, NULL);

    jclass callback_class = (*env)->GetObjectClass(env, args->callback_global);
    jmethodID on_output = (*env)->GetMethodID(env, callback_class, "onOutput", "(Ljava/lang/String;)V");

    char buffer[1024];
    FILE *fp = fdopen(args->pipe_fd, "r");
    if (fp != NULL) {
        while (fgets(buffer, sizeof(buffer), fp)) {
            emit_callback_string(env, args->callback_global, on_output, buffer);
        }
        fclose(fp);
    }

    (*env)->DeleteGlobalRef(env, args->callback_global);
    (*args->jvm)->DetachCurrentThread(args->jvm);
    free(args);
    return NULL;
}

JNIEXPORT void JNICALL
Java_uk_co_olilo_status_iperf_AndroidIperfRunner_forceStopIperfTest(
        JNIEnv *env,
        jobject thiz,
        jobject callback
) {
    (void) thiz;
    stop_requested = true;

    jclass callback_class = (*env)->GetObjectClass(env, callback);
    jmethodID on_output = (*env)->GetMethodID(env, callback_class, "onOutput", "(Ljava/lang/String;)V");
    emit_callback_string(env, callback, on_output, "[iPerf JNI] Requested graceful stop of iPerf test.\n");

    if (global_test && !global_test->done) {
        global_test->done = 1;
        iperf_set_send_state(global_test, IPERF_DONE);
        shutdown(global_test->ctrl_sck, SHUT_RDWR);
    }
}

JNIEXPORT void JNICALL
Java_uk_co_olilo_status_iperf_AndroidIperfRunner_runIperfLive(
        JNIEnv *env,
        jobject thiz,
        jobjectArray arguments,
        jobject callback
) {
    (void) thiz;
    jclass callback_class = (*env)->GetObjectClass(env, callback);
    jmethodID on_output = (*env)->GetMethodID(env, callback_class, "onOutput", "(Ljava/lang/String;)V");
    jmethodID on_error = (*env)->GetMethodID(env, callback_class, "onError", "(Ljava/lang/String;)V");
    jmethodID on_complete = (*env)->GetMethodID(env, callback_class, "onComplete", "()V");

    int argc = (*env)->GetArrayLength(env, arguments);
    if (argc > 64) {
        argc = 64;
    }

    char *argv[64];
    memset(argv, 0, sizeof(argv));
    for (int i = 0; i < argc; i++) {
        jstring arg = (jstring) (*env)->GetObjectArrayElement(env, arguments, i);
        const char *arg_str = (*env)->GetStringUTFChars(env, arg, 0);
        argv[i] = strdup(arg_str);
        (*env)->ReleaseStringUTFChars(env, arg, arg_str);
        (*env)->DeleteLocalRef(env, arg);
    }

    global_test = iperf_new_test();
    if (!global_test) {
        emit_callback_string(env, callback, on_error, "Failed to create iperf test");
        return;
    }
    iperf_defaults(global_test);

    int pipefd[2];
    if (pipe(pipefd) < 0) {
        emit_callback_string(env, callback, on_error, "Failed to create output pipe");
        iperf_free_test(global_test);
        global_test = NULL;
        return;
    }

    FILE *fp = fdopen(pipefd[1], "w");
    if (fp == NULL) {
        emit_callback_string(env, callback, on_error, "Failed to open output pipe");
        close(pipefd[0]);
        close(pipefd[1]);
        iperf_free_test(global_test);
        global_test = NULL;
        return;
    }
    setvbuf(fp, NULL, _IOLBF, 0);
    global_test->outfile = fp;

    if (iperf_parse_arguments(global_test, argc, argv) < 0) {
        fflush(fp);
        fclose(fp);
        emit_callback_string(env, callback, on_error, iperf_strerror(i_errno));
        iperf_free_test(global_test);
        global_test = NULL;
        for (int i = 0; i < argc; i++) {
            free(argv[i]);
        }
        return;
    }

    struct CallbackArgs *cb_args = malloc(sizeof(struct CallbackArgs));
    if (!cb_args) {
        emit_callback_string(env, callback, on_error, "Failed to allocate callback args");
        fclose(fp);
        iperf_free_test(global_test);
        global_test = NULL;
        for (int i = 0; i < argc; i++) {
            free(argv[i]);
        }
        return;
    }

    (*env)->GetJavaVM(env, &cb_args->jvm);
    cb_args->callback_global = (*env)->NewGlobalRef(env, callback);
    cb_args->pipe_fd = pipefd[0];
    pthread_create(&reader_thread, NULL, reader_thread_func, cb_args);

    emit_callback_string(env, callback, on_output, "[iPerf JNI] Initiating iPerf3 client request...\n");
    int result = iperf_run_client(global_test);
    if (result < 0 && global_test) {
        emit_callback_string(env, callback, on_error, iperf_strerror(i_errno));
    }

    fflush(fp);
    fclose(fp);

    if (global_test) {
        iperf_free_test(global_test);
        global_test = NULL;
    }

    pthread_join(reader_thread, NULL);

    for (int i = 0; i < argc; i++) {
        free(argv[i]);
    }

    if (stop_requested) {
        emit_callback_string(env, callback, on_output, "[iPerf JNI] Test was stopped by user.\n");
    } else if (result < 0) {
        emit_callback_string(env, callback, on_output, "[iPerf JNI] Test failed to complete successfully.\n");
    } else {
        emit_callback_string(env, callback, on_output, "[iPerf JNI] Test completed successfully.\n");
    }

    stop_requested = false;
    reader_thread = 0;
    (*env)->CallVoidMethod(env, callback, on_complete);
}
