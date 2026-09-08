#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");

const srcDir = path.join(__dirname, "src");
const distDir = path.join(__dirname, "dist");

const supabaseUrl = process.env.SUPABASE_URL || "";
const supabaseAnonKey = process.env.SUPABASE_ANON_KEY || "";

if (process.env.NETLIFY && (!supabaseUrl || !supabaseAnonKey)) {
  console.error(
    "Missing SUPABASE_URL or SUPABASE_ANON_KEY. Set both in Netlify site env vars before deploying."
  );
  process.exit(1);
}

fs.mkdirSync(distDir, { recursive: true });

for (const file of fs.readdirSync(srcDir)) {
  let contents = fs.readFileSync(path.join(srcDir, file), "utf8");
  contents = contents.split("__SUPABASE_URL__").join(supabaseUrl);
  contents = contents.split("__SUPABASE_ANON_KEY__").join(supabaseAnonKey);
  fs.writeFileSync(path.join(distDir, file), contents);
}

console.log("Wrote", distDir);
