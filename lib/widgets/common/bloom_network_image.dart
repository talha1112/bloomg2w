import 'package:flutter/material.dart';

/// A [NetworkImage] configured to fall back to a native HTML `<img>` element
/// on Flutter Web if the normal byte-fetch (XHR) request fails — e.g. due to
/// a browser/CORS/ad-blocker quirk on `firebasestorage.googleapis.com` URLs.
/// Behaves exactly like [NetworkImage] on mobile.
ImageProvider bloomNetworkImage(String url) {
  return NetworkImage(url, webHtmlElementStrategy: WebHtmlElementStrategy.fallback);
}
