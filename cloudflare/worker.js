const firebaseOrigin = 'https://farmapp-e2145.web.app';

export default {
  async fetch(request) {
    const incomingUrl = new URL(request.url);
    if (!incomingUrl.pathname.startsWith('/pay/')) {
      return fetch(request);
    }

    const upstreamUrl = new URL(
      `${incomingUrl.pathname}${incomingUrl.search}`,
      firebaseOrigin,
    );
    const upstreamRequest = new Request(upstreamUrl, request);
    const response = await fetch(upstreamRequest);

    if (!response.headers.get('content-type')?.includes('text/html')) {
      return response;
    }

    return new HTMLRewriter()
      .on('base', {
        element(element) {
          element.setAttribute('href', `${firebaseOrigin}/`);
        },
      })
      .transform(response);
  },
};
