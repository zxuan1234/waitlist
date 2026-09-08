# the task:


Build a landing page that collects email addresses for a waitlist.



\- Deploy it on Netlify (free tier is fine)

\- Store the submitted emails in Supabase (free tier is fine)

\- Any frontend approach you like — plain HTML/JS, React, whatever you're comfortable with



That's the whole brief. Anything not specified above is your call — I'm interested in the decisions you make when the requirements don't cover something.



Also send me a short write-up covering:



1\. Any assumptions you made, and gaps in the brief you had to fill in yourself

2\. What would break if this page suddenly received 10,000 signups in an hour

3\. Who can read the stored email addresses, and how you know that



A few notes



Please keep this to 3–4 hours. It's not meant to be polished or production-grade, and I'd rather see a smaller thing you fully understand than a bigger thing you don't.



You're welcome to use AI tools, I would assume you would. If you do, include a short note on where you used them and what you changed in the output. This isn't a trick question and using them won't count against you; I just want to talk about your code from the same starting point you did.



What I'll be looking at is your reasoning, not feature count.



To submit: send me the GitHub repo link, the live Netlify URL, and your write-up by Sep 11. We'll book the walkthrough after that.


Waitlist Landing Page — Build Spec
===

A plain-language spec for the take-home. Read the decision list, pick one option in each section, then fill in the "Locked spec" at the bottom. That becomes your build brief.

New terms are explained in boxes as they come up.

\---

## What they are actually looking at

The brief is short on purpose. Three sentences of requirements, then: *"Anything not specified above is your call."*

That sentence is the exercise. They are watching what you do when nobody tells you what to do.

The three write-up questions show you where they are looking:

|The question|What it is really testing|
|-|-|
|Assumptions and gaps you filled|Did you notice the brief was incomplete, or did you just start coding|
|What breaks at 10,000 signups/hour|Can you reason about the thing you built, or do you repeat things you have heard|
|Who can read the emails, and **how you know that**|Do you understand your own setup, and did you check it or just hope|

The third question is the hard one. "How you know that" is asking for proof, not confidence.

Here is the trap. Supabase can be set up so that anyone visiting your page can download every email you have collected. It is the default state, not an exotic mistake. If you never check, you will never find out, and you will answer question 3 wrong while feeling sure you are right.

**Your time budget is 3–4 hours.** They wrote: *"a smaller thing you fully understand than a bigger thing you don't."* Take that literally. Every feature you add is something you have to explain for 20 minutes to someone who writes code for a living.

\---

## The parts you cannot change

1. A landing page that collects email addresses
2. Deployed on Netlify (free tier)
3. Emails stored in Supabase (free tier)
4. Frontend is your choice
5. A short write-up answering the three questions
6. A note on where you used AI and what you changed

Everything else below is yours to decide.

\---

## Some background before the decisions

Skip this if you already know it.

> \*\*What Supabase is\*\*
>
> A hosted Postgres database with an HTTP API bolted on. Normally a database only speaks its own protocol, and you need a backend server to talk to it. Supabase adds a layer that lets you read and write the database over plain HTTPS requests. That is why a web page with no backend can still save data.

> \*\*The two Supabase keys\*\*
>
> Supabase gives you two API keys, and the difference matters enormously.
>
> The \*\*anon key\*\* ("anonymous") is meant to be public. It is designed to sit in your webpage's JavaScript where anyone can see it. It identifies your project, but it does not by itself grant permission to do anything.
>
> The \*\*service\_role key\*\* is the master key. It ignores every permission rule you set up. Anyone holding it can read, edit, or delete everything in your database. It must never appear in anything a browser downloads.

> \*\*What RLS is\*\*
>
> Row Level Security. It is a Postgres feature that decides, per row, whether a given requester is allowed to see or change it.
>
> This is the thing that actually protects your data, not the key. The anon key being public is fine \*because\* RLS is supposed to be doing the guarding.
>
> Two facts that catch people out:
> - RLS is \*\*off by default\*\* on a new table. Off means no restrictions, so anyone with the anon key can read everything.
> - Once you turn RLS on, the default flips to deny. A table with RLS on and zero policies allows nothing. You then add policies to allow specific actions back in.
>
> So "RLS on, one INSERT policy, no SELECT policy" means: strangers can add their email, but cannot read anybody's.

> \*\*What a Netlify Function is\*\*
>
> A small piece of backend code that Netlify runs for you. You do not manage a server. You write a file, Netlify makes it available at a URL, and it runs when someone hits that URL, then shuts down.
>
> This gives you a place to run code that the visitor cannot see or tamper with. Useful for holding secrets.

\---

## The decisions

### 1\. How does the email get into Supabase?

This is the big one. Everything else follows from it.

**Option A — the browser talks to Supabase directly**

Your page's JavaScript sends the email straight to Supabase using the anon key. The database's RLS policies are the only thing standing between a stranger and your data.

Good:

* Very little code. No backend at all.
* The anon key is meant to be public, so putting it in your page is not the mistake people think it is.
* It forces you to actually learn RLS, which is exactly what question 3 is about.

Bad:

* All your safety sits in one policy. Write it wrong and your list is public.
* There is no server-side place to add checks later, because there is no server.

**Option B — the browser talks to a Netlify Function, which talks to Supabase**

Your page sends the email to your own function. The function holds the service\_role key (stored as a Netlify setting, never in your code) and writes to the database. The database can then refuse the outside world entirely.

Good:

* No key in the browser at all.
* You have a private place to run checks: validation, spam filtering, logging.

Bad:

* More pieces to build and explain.
* Cold starts. The function is not running until someone calls it, so the first request after a quiet period waits a second or so for it to boot.
* If the service\_role key ever leaks, RLS cannot save you. It ignores RLS by design.

> \*\*My suggestion for 3–4 hours:\*\* Option A. It is less code and it puts you nose-to-nose with the exact topic question 3 asks about.
>
> But Option B is equally correct, and it is the better answer if you want somewhere to put spam protection.
>
> What matters is not which you pick. It is being able to say, in the walkthrough, why the other one was wrong \*for your situation\*. "I picked A because with a 3-hour budget I wanted one security model to get right rather than two components to wire together" is a good answer. Shrugging is not.

\---

### 2\. What happens when someone signs up twice?

* **Block it and say so** — "you're already on the list." Simple, but it tells anyone who asks whether a given email is signed up. Someone could test addresses one by one to find out who is on your list.
* **Block it, but show the same message either way** — the user always sees "you're on the list," whether they were new or not. No information leaks. Slightly more code: you catch the duplicate error and pretend it succeeded.
* **Let the database ignore it** — Postgres has `ON CONFLICT DO NOTHING`, which silently skips a duplicate insert. One line, clean.
* **Allow duplicates** — fine for 3 hours only if you say out loud that you chose it.

> \*\*Uniqueness\*\* is enforced with a \*unique constraint\* on the email column. It is a rule the database itself enforces, so it holds even if your JavaScript has a bug.
>
> The second option is a nice small choice to make. It shows you thought about what your error messages give away.

\---

### 3\. What do you store besides the email?

Every extra column is personal data you now have to justify.

* `id`, `email`, `created\_at` — the minimum
* `ip\_address` — useful for spotting abuse, but it counts as personal data under privacy law and makes a leak worse. Only store it if you have a reason.
* `user\_agent` — which browser they used. Low value, more tracking.
* `referrer` / UTM tags — where they came from. Real marketing value in a real product.

> \*\*PII\*\* means Personally Identifiable Information: data that can identify a specific person. An email address is PII. An IP address usually counts too. Storing PII brings obligations under laws like GDPR, mainly around consent, and around deleting it when someone asks.

> The stronger move here is storing less, and explaining in your write-up \*why you left IP out\*. "I didn't need it, and it would have widened what a breach exposes" reads better than a table full of fields you never use.

\---

### 4\. Checking the email is valid

* **HTML's `type="email"`** — the browser shows a warning for obvious junk. Nice for users. Not protection: anyone can bypass it by editing the page or sending the request directly with a tool like curl.
* **Add JavaScript checks** — better user experience, still bypassable for the same reason.
* **Check in your Netlify Function** — only possible with Option B. Cannot be bypassed, because it runs on the server.
* **Add a database `CHECK` constraint** — works with either option. A rule the database enforces on every insert, no matter where it came from. Cheap and very hard to get around.

> \*\*The general principle:\*\* anything running in the browser is a suggestion, not a rule. The visitor controls their own browser. Real enforcement has to happen somewhere they cannot reach: your function, or the database.

> Also worth saying in your write-up: you cannot tell whether an email address actually exists without sending mail to it. All you can check here is the shape of the string.

\---

### 5\. Stopping spam and bots

This connects straight to question 2. 10,000 signups in an hour looks a lot like a bot.

* **Nothing, and say so** — a fair choice for the time budget, as long as you can describe what you would add first.
* **A honeypot field** — a hidden input that real users never see and never fill. Bots fill in every field they find. If it has a value, quietly discard the submission but show a success message so the bot does not learn. About five minutes of work, no friction for real users.
* **Turnstile or hCaptcha** — proper bot protection from Cloudflare or similar. Effective, but adds a third-party service and setup time.
* **Rate limiting by IP** — capping how many signups one address can send per minute. Needs Option B, plus somewhere to keep a count, which is awkward on free serverless.

> Honeypot is the best value for the time. It also gives you something concrete to point at when they ask about the 10,000 scenario.

\---

### 6\. Things to deliberately leave out

Decide, then write the decision down. An acknowledged gap is worth more than a silent one.

* **Confirmation email (double opt-in)** — sending a "click to confirm" email before adding someone. Out of scope here, but a real waitlist needs it, partly so people cannot sign up someone else's address.
* **Unsubscribe or delete link** — also out of scope, but note it. You are collecting personal data with no way for anyone to get it removed, which a real product cannot do.
* **What the waitlist is even for** — the brief never says what product people are joining. You have to invent one. That is a genuine gap worth naming in the write-up.
* **Analytics** — skip it.
* **Custom domain** — skip it. The free `something.netlify.app` address is fine.

\---

### 7\. Which frontend

* **Plain HTML, CSS, and a little JavaScript** — no build step, deploys as-is, nothing to explain away. For one form, this is a strong choice and it matches their "smaller thing you fully understand" note exactly.
* **React with Vite** — familiar and fine, but you are shipping a whole framework to render one text box and one button. Be ready to justify it.
* **Astro or 11ty** — nice output, more tooling to explain.

> \*\*A build step\*\* is a compilation stage: tools like Vite turn your source files into the plain HTML/CSS/JS a browser can actually run. Frameworks need one. Plain HTML does not, which is one less thing that can break during deployment.

> Choosing React here is itself a signal. Not a bad one, but have a better reason than "it is what I know."

\---

### 8\. Making it usable

These are quick and they get noticed:

* A real `<label>` on the input, not just placeholder text. Screen readers ignore placeholders, and the text vanishes once someone starts typing.
* An `aria-live="polite"` region for your success and error messages, so screen readers announce them when they appear.
* Disable the button while the request is in flight, and show that something is happening. Stops double submissions.
* Move keyboard focus to the status message when it appears.
* Error messages that separate "your input was wrong" from "something on our end broke."

> \*\*`aria-live`\*\* marks a region of the page as one that updates. Assistive software watches it and reads out changes. Without it, a sighted user sees "Thanks, you're on the list!" appear and a screen reader user hears nothing at all.

\---

### 9\. Handling keys and secrets

* **Option A:** the Supabase URL and anon key end up in your page, which is fine. Still, store them as Netlify environment variables and read them in, so the good habit shows.
* **Option B:** the service\_role key goes in a Netlify environment variable only. Never in the repo. Never in a variable whose name starts with `VITE\_` or `PUBLIC\_` — those prefixes tell build tools to bake the value into the browser bundle, which defeats the entire point.
* Commit a `.env.example` with the variable names and empty values, so someone can see what is needed without seeing your actual keys.
* Add `.env` to `.gitignore` **before** your first commit. Git remembers everything, so removing a key later does not remove it from history.

> \*\*Environment variables\*\* are settings you configure in Netlify's dashboard rather than writing into your code. Your code reads them at build or run time. This keeps secrets out of the files you push to GitHub.

\---

## How to answer Question 3 properly

This is the highest-value 15 minutes of the whole exercise. Do not reason about your setup. Test it, and paste the result into your write-up.

**Step 1: list everyone who can read the emails.**

1. **You**, through the Supabase dashboard, plus anyone you invited to the project
2. **Anyone holding the service\_role key** — it ignores RLS completely, so no policy can stop it
3. **Anyone holding the anon key** — which, in Option A, is *everyone who loads your page*. Whether they can actually read anything depends entirely on your RLS policies.
4. **Anyone with admin access to your Netlify site** — they can view the environment variables
5. **Supabase and Netlify themselves**, per their terms of service. Worth one sentence.

**Step 2: prove point 3 instead of assuming it.**

First, check the setup. In the Supabase SQL editor:

```sql
-- Is RLS actually turned on? If relrowsecurity is false, your policies do nothing.
select relname, relrowsecurity from pg\_class where relname = 'waitlist';

-- What policies exist?
select \* from pg\_policies where tablename = 'waitlist';
```

Then try to read the table the way a stranger would. Run this from your terminal:

```bash
# Try to read every row using the public anon key
curl "https://YOUR\_PROJECT.supabase.co/rest/v1/waitlist?select=\*" \\
  -H "apikey: YOUR\_ANON\_KEY" \\
  -H "Authorization: Bearer YOUR\_ANON\_KEY"

# You want back:  \[]
#   RLS is on with no SELECT policy, so rows are filtered out. Empty list, no error.
#
# You do NOT want:  a JSON array containing every email you have collected.
#   That means RLS is off, and your waitlist is public.
```

Then confirm you did not break your own form:

```bash
curl -X POST "https://YOUR\_PROJECT.supabase.co/rest/v1/waitlist" \\
  -H "apikey: YOUR\_ANON\_KEY" \\
  -H "Authorization: Bearer YOUR\_ANON\_KEY" \\
  -H "Content-Type: application/json" \\
  -d '{"email":"rls-test@example.com"}'
```

> \*\*curl\*\* is a command-line tool that sends HTTP requests. It is how you talk to your API without a browser, which is the point: it proves that a stranger with the key and no browser still cannot read your data.

**The trap to watch for:** an empty table with RLS *off* returns `\[]` too. It looks identical to a properly protected table. So insert a row first, then run the read test. Otherwise you have proved nothing.

Noticing that distinction, and mentioning it, is a genuinely good thing to say in the walkthrough.

\---

## How to answer Question 2 honestly

10,000 signups in an hour works out to under 3 per second. That is a small number. Do not perform panic about it.

Walk through what is actually true for *your* build:

* **The page itself** is served from Netlify's CDN, a network of servers that hold copies of your files worldwide. It is built for far more than this. Not your bottleneck.
* **Option A:** the browser writes straight to Supabase. Three inserts per second is nothing for Postgres. The thing to actually go and look up is the free tier's monthly request and bandwidth limits.
* **Option B:** Netlify's free tier caps monthly function requests and total runtime. Check the current numbers on their site rather than guessing. Cold starts add delay at the start of a rush, but do not limit throughput.
* **Storage:** 10,000 rows of email plus a timestamp is well under a megabyte. Nowhere near any limit.
* **What breaks first:** honestly, probably nothing technical. The real problem is that with no rate limiting and no duplicate handling, 10,000 signups in an hour is probably *not 10,000 people*. You now have a list you cannot trust, which is a worse outcome than a slow page.
* **What you would add, in order:** rate limiting, then bot protection, then an alert when the signup rate spikes.

> Answering "not much breaks, here is what would break at 100 times this, and here is what breaks socially even at this rate" is a much better answer than listing optimisations nobody needs.
>
> Be clear about which numbers you looked up and which you estimated. Saying "I checked Netlify's docs for this, but I'm estimating the Supabase side" is a strength, not a hedge.

\---

## What to hand in

```
repo/
├── README.md          # what it is, how to run it, link to the live site
├── WRITEUP.md         # the three answers + your AI note
├── .env.example       # variable names, empty values
├── index.html         # or src/, depending on section 7
├── schema.sql         # your table and RLS policies
└── netlify.toml       # Netlify config
```

Include `schema.sql` even though you could set everything up by clicking around Supabase's dashboard. Putting your table definition and security policies in a file means the reviewer can read your security decisions instead of taking your word for them. That directly supports question 3.

\---

## The AI usage note

They asked for it, and said it will not count against you: *"I just want to talk about your code from the same starting point you did."*

Write it as a short, specific log:

* Which tool, for which parts
* What you changed in its output and why — **this is the part they are actually reading**
* Anything it produced that you threw away, and why
* Anything you do not fully understand (there should be very little, given the "fully understand" note — if there is, cut that feature rather than shipping it)

The weak version is "used AI for boilerplate."

The strong version is specific: *"I asked it for the RLS policy. What it gave me granted read access to anon by default. I removed that and verified with curl that reads now return empty."*

That one sentence answers the AI question and question 3 at the same time, and it shows you read the output instead of pasting it.

\---

## Locked spec

Fill this in before you write any code, then build only what is listed.

* **How the email reaches Supabase:** *A (direct)* 
* **Frontend:** HTML + CSS +JavaScript
* **Duplicate handling:** **Let the database ignore it** — Postgres has `ON CONFLICT DO NOTHING`, which silently skips a duplicate insert. One line, clean.
* **Columns stored:** `id`、`email`、`created\_at`
* **Where validation happens:** **Add JavaScript checks** — better user experience, still bypassable for the same reason.
* **Check in your Netlify Function** — only possible with Option B. Cannot be bypassed, because it runs on the server.
* **Add a database `CHECK` constraint** — works with either option. A rule the database enforces on every insert, no matter where it came from. Cheap and very hard to get around.
* **Spam protection:** honeypot
* **Deliberately out of scope:** \_\_\_\_\_\_\_

If anything here pushes you past four hours, cut it and move it to a "what I'd do next" section in the write-up. A gap you named on purpose scores better than a feature you rushed.

