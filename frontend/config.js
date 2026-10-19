const globalScope = typeof window !== "undefined" ? window : globalThis;
const hostname = (typeof window !== "undefined" && window.location && window.location.hostname) ? window.location.hostname : "localhost";

globalScope.API_URL = globalScope.API_URL || `http://${hostname}:8000`;
globalScope.NOTIFICATION_URL = globalScope.NOTIFICATION_URL || `http://${hostname}:8001`;

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    API_URL: globalScope.API_URL,
    NOTIFICATION_URL: globalScope.NOTIFICATION_URL,
  };
}
