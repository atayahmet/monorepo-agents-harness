# Simple English — write short, clear sentences

## **Every harness file and developer message is written in simple English**

The harness writes specs, plans, memory, verify files, intents, ADRs, changesets, knowledge
base pages, review reports, and commit messages, and talks to the developer with questions,
summaries, and reports. All of this text MUST be simple English.

Many developers are not native English speakers. Long sentences and rare words are slow to
read and easy to misread. Simple English is the same technical content, in shorter sentences
and common words.

## Rules

- **One idea per sentence.** Split long sentences.
- **Use common words.** Say "use", not "utilize"; "start", not "initiate".
- **Use active voice.** "The hook checks the file", not "The file is checked by the hook".
- **Keep sentences short.** Aim for at most 20 words.
- **Use lists, not long paragraphs.**
- **Keep technical terms exact** — file names, commands, paths. Explain uncommon terms once.

## Examples (bad → good)

Bad: "Following the completion of the implementation phase, the memory file, which captures
the durable outcomes of the session, must be generated and then ingested into the knowledge
base for the purpose of ensuring the efficient utilization of the accumulated knowledge."

Good: "Write the memory file at task end. It stores what the task changed. Then ingest it
into the knowledge base."

Bad: "Given the aforementioned constraints, would you kindly indicate your preference
regarding the manner in which we should proceed with the implementation of the migration
strategy?"

Good: "The migration has two options. Option A keeps the current API. Option B rewrites it.
Which one do you want?"

## Applies to

- Every file the harness generates and every message to the developer.