import { test } from "node:test";
import assert from "node:assert/strict";
import { parseCommand, toUrl, pickTab } from "../extension/commands.js";

test("search verb and bare text both search Google", () => {
  const url = "https://www.google.com/search?q=keyboard%20layouts";
  assert.equal(parseCommand("search keyboard layouts").url, url);
  assert.equal(parseCommand("keyboard layouts").url, url);
});

test("engine verbs", () => {
  assert.match(parseCommand("yt lofi beats").url, /^https:\/\/www\.youtube\.com\/results\?search_query=lofi%20beats$/);
  assert.match(parseCommand("ask what is MV3").url, /^https:\/\/claude\.ai\/new\?q=/);
  assert.match(parseCommand("gpt hi").url, /^https:\/\/chatgpt\.com\/\?q=hi$/);
});

test("a verb with no argument is just a search", () => {
  assert.equal(parseCommand("yt").url, "https://www.google.com/search?q=yt");
});

test("open and bare addresses", () => {
  assert.equal(parseCommand("open github.com").url, "https://github.com/");
  assert.equal(parseCommand("open instagram").url, "https://instagram.com/");
  assert.equal(parseCommand("open gmail").url, "https://mail.google.com");
  assert.equal(parseCommand("news.ycombinator.com").url, "https://news.ycombinator.com/");
  assert.equal(parseCommand("localhost:3000/app").url, "http://localhost:3000/app");
});

test("toUrl refuses non-http schemes", () => {
  assert.equal(toUrl("javascript:alert(1)"), null);
  assert.equal(toUrl("data:text/html,hi"), null);
  assert.equal(toUrl("two words"), null);
});

test("go / note", () => {
  assert.deepEqual(
    { ...parseCommand("go gmail"), label: undefined },
    { action: "switch", query: "gmail", fallbackUrl: "https://mail.google.com", label: undefined }
  );
  assert.equal(parseCommand("note buy milk").text, "buy milk");
  assert.equal(parseCommand("   "), null);
});

test("pickTab prefers hostname, then title, never the current tab", () => {
  const tabs = [
    { id: 1, url: "https://www.instagram.com/", title: "Instagram" },
    { id: 2, url: "https://mail.google.com/mail/u/0", title: "Inbox (3) - Gmail" },
    { id: 3, url: "https://notes.example.com", title: "gmail draft ideas" },
  ];
  assert.equal(pickTab(tabs, "mail.google", 9).id, 2);
  assert.equal(pickTab(tabs, "gmail", 9).id, 2);
  assert.equal(pickTab(tabs, "insta", 1), null);
  assert.equal(pickTab(tabs, "insta", 9).id, 1);
});
