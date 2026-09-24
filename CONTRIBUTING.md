# Contributing

Thanks for taking a look! Issues and pull requests both live at
https://github.com/VeryGoodOpenSource/genui_jaspr. If something in the README did not
match what the package did, that is a bug too, so please file it.

## Running the tests

There are three suites, and each reaches code the others cannot.

```sh
dart test                          # the package, on the VM
dart test -p chrome test/browser   # the browser-only tests, needs Chrome
cd example && ./tool/coverage.sh   # the example, VM and browser, with coverage
```

### The package suite

`dart test` runs everything under `test/` except the browser folder. It drives
the real message processor, the real binder, and the real catalog, and asserts on
the HTML that comes out, so what is under test is the same path production uses.
CI holds this suite at 100% line coverage of `lib/`.

### Why there are browser tests

The browser tests are marked `@TestOn('browser')`, so a plain `dart test` skips
them. They exist because a few hops cannot be reached from the VM: a real
keystroke or click on a real input element reaching the data model (a text
field, checkbox, radio, checkbox group, range, or date/time input), a real
click on a generated button, and a textarea whose displayed value follows the
data model after the user has typed in it. Deleting a field's `onInput`
handler passes every VM test and fails here, which is why this suite is worth
the Chrome dependency.

The few lines in `lib/` that only a browser can execute are marked with
`coverage:ignore` comments that say so, and each has a browser test.

### The example suite

The example is a separate workspace member, so a root `dart test` does not reach
it. Its `tool/coverage.sh` runs the VM suite, then the browser suite for
`chat.dart`, and merges the two coverage reports, because neither platform alone
can reach all of the code: the Genkit agent only runs on the VM, and `chat.dart`
is a `@client` component that only runs in a browser. `tool/merge_lcov.dart`
explains how the two reports combine. CI holds the merged number at 100%.

The round-trip test starts a real server and drives the real agent with a
stand-in for the model, so everything between browser and model is covered
without an API key. Only the model call itself needs one.

## Before opening a pull request

CI runs formatting, analysis with `--fatal-infos`, the three suites above, a
[pana](https://pub.dev/packages/pana) score, a licence check, and a spell check
over the whole repo with the dictionary in `.github/cspell.json`. Running these
locally first saves a round trip:

```sh
dart format --set-exit-if-changed lib test example/lib example/test
dart analyze --fatal-infos
npx cspell --config .github/cspell.json "**/*.{dart,md,yaml}"
./tool/coverage.sh
```

Pull request titles become the squash-merge commit titles, so they follow the
conventional `type: summary` shape and read as a changelog line.
