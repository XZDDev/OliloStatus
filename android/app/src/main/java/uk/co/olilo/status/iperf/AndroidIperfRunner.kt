package uk.co.olilo.status.iperf

interface AndroidIperfCallback {
    fun onOutput(line: String)
    fun onError(error: String)
    fun onComplete()
}

object AndroidIperfRunner {
    init {
        System.loadLibrary("oliloiperf")
    }

    @JvmStatic
    external fun runIperfLive(arguments: Array<String>, callback: AndroidIperfCallback)

    @JvmStatic
    external fun forceStopIperfTest(callback: AndroidIperfCallback)
}
