#!/usr/bin/env node
// Draws the iOS and Android app icons from the gold G of the phone's back
// button, written by export.mjs, on the apps' dark ground, and gives iOS the
// tab icons and the wordmark that Android draws as vectors.
//
//   node script/pixel_art/app_icons.mjs
//
// The output is deterministic: running it again changes no file.

import { mkdirSync, readFileSync, writeFileSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"
import { deflateSync } from "node:zlib"

const root = join(dirname(fileURLToPath(import.meta.url)), "../..")
const GROUND = "#0b0f15"

const G_WIDTH = 37
const G_HEIGHT = 50

const IOS_SIDE = 1024
const IOS_SCALE = 14
const IOS_ICON = "mobile/ios/Gameble/Assets.xcassets/AppIcon.appiconset/AppIcon.png"

// An adaptive icon is drawn on 108 units, of which launchers always show the
// centred circle of 66; one art pixel per unit keeps the whole G inside it.
const ANDROID_SIDE = 108
const ANDROID_ICON = "mobile/android/app/src/main/res/drawable/ic_launcher_foreground.xml"

function colourRuns() {
  const svg = readFileSync(join(root, "app/frontend/images/pixel/back-g.svg"), "utf8")
  return [...svg.matchAll(/<path\b[^>]*>/g)].map(([tag]) => ({
    fill: tag.match(/fill="(#[0-9a-fA-F]{6})"/)[1],
    data: tag.match(/\bd="([^"]+)"/)[1],
  }))
}

const rgb = (hex) => [1, 3, 5].map((start) => parseInt(hex.slice(start, start + 2), 16))

const runsOf = (data) =>
  [...data.matchAll(/M(\d+) (\d+)h(\d+)/g)].map(([, x, y, width]) => ({
    x: Number(x),
    y: Number(y),
    width: Number(width),
  }))

function iosPixels(paths) {
  const pixels = Buffer.alloc(IOS_SIDE * IOS_SIDE * 3)
  for (let at = 0; at < pixels.length; at += 3) pixels.set(rgb(GROUND), at)
  const left = Math.floor((IOS_SIDE - G_WIDTH * IOS_SCALE) / 2)
  const top = Math.floor((IOS_SIDE - G_HEIGHT * IOS_SCALE) / 2)
  for (const { fill, data } of paths) {
    for (const { x, y, width } of runsOf(data)) {
      for (let row = 0; row < IOS_SCALE; row++) {
        const start = (top + y * IOS_SCALE + row) * IOS_SIDE + left + x * IOS_SCALE
        for (let column = 0; column < width * IOS_SCALE; column++) pixels.set(rgb(fill), (start + column) * 3)
      }
    }
  }
  return pixels
}

const CRC_TABLE = Array.from({ length: 256 }, (_, index) => {
  let value = index
  for (let bit = 0; bit < 8; bit++) value = value & 1 ? 0xedb88320 ^ (value >>> 1) : value >>> 1
  return value >>> 0
})

function crc32(bytes) {
  let crc = 0xffffffff
  for (const byte of bytes) crc = CRC_TABLE[(crc ^ byte) & 0xff] ^ (crc >>> 8)
  return (crc ^ 0xffffffff) >>> 0
}

function pngChunk(type, data) {
  const body = Buffer.concat([Buffer.from(type, "ascii"), data])
  const length = Buffer.alloc(4)
  length.writeUInt32BE(data.length)
  const crc = Buffer.alloc(4)
  crc.writeUInt32BE(crc32(body))
  return Buffer.concat([length, body, crc])
}

// The App Store refuses an icon with an alpha channel: colour type 2 has none.
function opaquePng(side, pixels) {
  const header = Buffer.alloc(13)
  header.writeUInt32BE(side, 0)
  header.writeUInt32BE(side, 4)
  header.set([8, 2, 0, 0, 0], 8)
  const rows = []
  for (let row = 0; row < side; row++) {
    rows.push(Buffer.from([0]), pixels.subarray(row * side * 3, (row + 1) * side * 3))
  }
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    pngChunk("IHDR", header),
    pngChunk("IDAT", deflateSync(Buffer.concat(rows), { level: 9 })),
    pngChunk("IEND", Buffer.alloc(0)),
  ])
}

function androidVector(paths) {
  const shapes = paths
    .map(
      ({ fill, data }) => `        <path
            android:fillColor="#FF${fill.slice(1).toUpperCase()}"
            android:pathData="${data}" />`,
    )
    .join("\n")
  return `<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="${ANDROID_SIDE}dp"
    android:height="${ANDROID_SIDE}dp"
    android:viewportWidth="${ANDROID_SIDE}"
    android:viewportHeight="${ANDROID_SIDE}">
    <group
        android:translateX="${Math.floor((ANDROID_SIDE - G_WIDTH) / 2)}"
        android:translateY="${(ANDROID_SIDE - G_HEIGHT) / 2}">
${shapes}
    </group>
</vector>
`
}

function iosVectorImage(name, androidDrawable, renderingIntent) {
  const vector = readFileSync(join(root, "mobile/android/app/src/main/res/drawable", `${androidDrawable}.xml`), "utf8")
  const attribute = (key) => vector.match(new RegExp(`android:${key}="([^"]+)"`))[1]
  const shapes = [...vector.matchAll(/android:fillColor="#FF([0-9A-Fa-f]{6})"\s+android:pathData="([^"]+)"/g)]
    .map(([, colour, data]) => `<path fill="#${colour.toLowerCase()}" d="${data}"/>`)
    .join("")
  const size = (key) => parseInt(attribute(key), 10)
  const svg =
    `<svg xmlns="http://www.w3.org/2000/svg" width="${size("width")}" height="${size("height")}" ` +
    `viewBox="0 0 ${attribute("viewportWidth")} ${attribute("viewportHeight")}" shape-rendering="crispEdges">${shapes}</svg>\n`
  const contents = {
    images: [{ filename: `${name}.svg`, idiom: "universal" }],
    info: { author: "xcode", version: 1 },
    properties: { "preserves-vector-representation": true, "template-rendering-intent": renderingIntent },
  }
  const folder = join(root, "mobile/ios/Gameble/Assets.xcassets", `${name}.imageset`)
  mkdirSync(folder, { recursive: true })
  writeFileSync(join(folder, `${name}.svg`), svg)
  writeFileSync(join(folder, "Contents.json"), `${JSON.stringify(contents, null, 2)}\n`)
}

const paths = colourRuns()
writeFileSync(join(root, IOS_ICON), opaquePng(IOS_SIDE, iosPixels(paths)))
writeFileSync(join(root, ANDROID_ICON), androidVector(paths))
for (const tab of ["hub", "capsule", "sets", "friends", "trades"]) iosVectorImage(`tab-${tab}`, `ic_tab_${tab}`, "template")
iosVectorImage("wordmark", "wordmark", "original")
