# xenchord

Helper methods/classes for livecoding just intonation music in Sonic Pi.

(work in progress)

## Configuration

See variables in in [prelude_for_livecoding.rb](/prelude_for_livecoding.rb)

## Development

To get a semantic highlighting & autocomplete suggestions, use [ruby-lsp](https://github.com/Shopify/ruby-lsp)

However, both ruby-lsp and ruby-lsp-vscode is currently broken on Windows, so you'll have to connect VSCode to a remote server running WSL and install the ruby-lsp extension on the remote server.

Track the PRs regarding the issues here:

- https://github.com/Shopify/ruby-lsp/pull/841
- https://github.com/Shopify/vscode-ruby-lsp/pull/712

### Note:

Referencing Sonic Pi's "global-scope context" inside classes requires using the `$GLO` prefix defined in [prelude_for_livecoding.rb](/prelude_for_livecoding.rb) as Sonic Pi's global context is different from the scope which classes are defined in (which are actually default Ruby global scope).
