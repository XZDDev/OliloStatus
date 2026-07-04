import SwiftUI
import WebKit

struct OliloWebViewSheet: View {
    let title: String
    let url: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            OliloWebView(url: url)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                        .foregroundStyle(Color.oliloPurple)
                    }
                }
        }
    }
}

struct OliloIframeWebViewSheet: View {
    let title: String
    let url: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            OliloIframeWebView(url: url)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                        .foregroundStyle(Color.oliloPurple)
                    }
                }
        }
        .tint(Color.oliloPurple)
    }
}

private struct OliloWebView: UIViewRepresentable {
    let url: URL

    /// Creates the backing web view and loads the requested URL.
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.load(URLRequest(url: url))
        return webView
    }

    /// Leaves the loaded page unchanged after SwiftUI state updates.
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

private struct OliloIframeWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        loadIframe(in: webView)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    private func loadIframe(in webView: WKWebView) {
        let sourceURL = url.absoluteString
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        let html = """
        <!doctype html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
            <style>
                html, body, iframe {
                    width: 100%;
                    height: 100%;
                    margin: 0;
                    padding: 0;
                    border: 0;
                    background: #000;
                    overflow: hidden;
                }
            </style>
        </head>
        <body>
            <iframe src="\(sourceURL)" allowfullscreen loading="eager"></iframe>
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: url)
    }
}
