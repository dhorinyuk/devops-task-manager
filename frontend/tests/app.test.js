const test = require("node:test");
const assert = require("node:assert");
const { escapeHtml } = require("../app.js");
const config = require("../config.js");

test("escapeHtml should escape HTML special characters", () => {
  const input = '<script>alert("hello & welcome");</script>';
  const expected = "&lt;script&gt;alert(&quot;hello &amp; welcome&quot;);&lt;/script&gt;";
  assert.strictEqual(escapeHtml(input), expected);
});

test("escapeHtml should handle plain strings and numbers correctly", () => {
  assert.strictEqual(escapeHtml("Clean task title"), "Clean task title");
  assert.strictEqual(escapeHtml(12345), "12345");
});

test("config should have valid default API and NOTIFICATION URLs", () => {
  assert.ok(config.API_URL.startsWith("http://"));
  assert.ok(config.NOTIFICATION_URL.startsWith("http://"));
  assert.ok(config.API_URL.includes(":8000"));
  assert.ok(config.NOTIFICATION_URL.includes(":8001"));
});
