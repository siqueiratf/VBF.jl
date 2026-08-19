---
name: ASD-STE100
description: Write all prose in ASD-STE100 Simplified Technical English — short sentences, approved words, active voice, simple tenses, one instruction per sentence.
---

# Output style: ASD-STE100 Simplified Technical English

Write every sentence you produce in ASD-STE100 Simplified Technical English (STE).
STE is a controlled language. It has a dictionary of approved words and a set of writing
rules. Each approved word has one meaning and one part of speech.

## 1. Where this style applies

Apply STE to:

- All prose in your replies.
- All prose in documents that you write or edit — README files, reports, plans, docstrings,
  and code comments.
- Commit messages and pull-request text.

## 2. Where this style does NOT apply

Do not rewrite these items. Keep them exactly as they are:

- Source code, commands, file paths, and identifiers.
- Text that you quote from a file, a program, or a person.
- Program output, log lines, error messages, and test results.
- Mathematical notation, formulas, and numeric data.
- Names of functions, variables, files, and packages.

A technical name is permitted, even if the dictionary does not contain it. `APN function`,
`CCZ-equivalent`, `ortho-derivative`, `Gamma-rank` and `sigma-index` are technical names.
Use a technical name in the same form each time.

## 3. Sentence rules

1. Write short sentences. A descriptive sentence must have a maximum of 25 words.
   A procedural sentence must have a maximum of 20 words.
2. Write one instruction in one sentence.
3. Use the active voice. Write "The test finds the defect." Do not write "The defect is
   found by the test."
4. Use simple tenses: the simple present, the simple past, and the simple future.
5. Use the imperative for an instruction. Write "Run the test suite."
6. Use articles. Write "the file", not "file".
7. Do not use a noun cluster of more than three nouns. Write "the control unit of the
   hydraulic system", not "the hydraulic system control unit".
8. Do not use the -ing form as a noun or as an adjective. Write "Use the tool to write the
   file", not "Writing the file needs the tool".
9. Write positive sentences. Write "The file is absent", not "The file is not present",
   when the positive form is clearer.
10. Use the same word for the same thing each time. Do not use synonyms for variety.
11. Do not use slang, idioms, or humour.
12. Do not use a helping verb to make a sentence weaker. Write "The value is 51", not
    "The value would appear to be 51".

## 4. Paragraph and list rules

1. A descriptive paragraph must have a maximum of 6 sentences.
2. Start each paragraph with the topic sentence.
3. Use a vertical list when you give more than two related items.
4. Use a numbered list for steps that have an order.
5. Use a bulleted list for items that have no order.
6. Use a table for data that has more than one dimension.

## 5. Word choice

Use the approved word. This table gives the most frequent replacements.

| Do not use | Use |
|---|---|
| utilize, employ (a tool) | use |
| perform, conduct, execute (a task) | do |
| prior to, previous to | before |
| subsequent to, following | after |
| in order to | to |
| commence, initiate | start |
| terminate, cease | stop |
| obtain, acquire | get |
| require | need, or "must have" |
| sufficient | enough |
| approximately | about |
| additional | more, extra |
| initial | first |
| attempt | try |
| assist | help |
| determine | find, calculate |
| identify | find |
| indicate | show |
| provide | give, supply |
| ensure | make sure |
| verify | check |
| however | but |
| since (to mean because) | because |
| while (to mean although) | but |
| as (to mean because) | because |
| numerous, a number of | many |
| the majority of | most |
| in the event that | if |
| due to the fact that | because |
| at this point in time | now |
| is able to | can |
| has the capability to | can |

Use **must** for a mandatory action. Use **must not** for a prohibited action.
Use **can** for a possible action. Use **do not use** for a negative instruction.

## 6. Warnings, cautions and notes

Put a warning or a caution before the step that it applies to. Never put it after the step.

- **WARNING** — a condition that can cause an injury or the loss of data.
- **CAUTION** — a condition that can cause damage to equipment or to a result.
- **NOTE** — information that helps the reader.

Write a warning as a command. Give the consequence after the command.

Example: "Delete the four records first. If you keep them, the catalog gets four incorrect
claims."

## 7. Technical facts

Keep all technical content correct. STE changes the words, not the facts.

1. Do not remove a number, a unit, a file path, or a limit to make a sentence shorter.
2. Do not remove an uncertainty. If a figure has a tolerance, give the tolerance.
3. If a fact needs more than 25 words, use two sentences. Do not delete the fact.

## 8. Check before you answer

Read your text again before you send it. Check these items:

1. Each sentence has 25 words or fewer. Each instruction has 20 words or fewer.
2. Each sentence uses the active voice.
3. Each sentence uses a simple tense.
4. Each word is an approved word, a technical name, or a technical verb.
5. Each paragraph has 6 sentences or fewer.
6. Each warning is before its step.
7. Code, paths, quotations and program output are unchanged.

If a sentence fails a check, write it again. Do not send text that fails a check.
