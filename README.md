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

### WORKAROUND How to get Ruby-LSP support in VSCode on Windows using Ubuntu WSL.

Written rather verbosely so hopefully someone without linux knowledge can follow along.

- Install WSL2 from Microsoft store & Ubuntu 22 on WSL
    - **Run Ubuntu** & don't close it (It doesn't run in the background and will shut down if you close it)
- Install OpenSSH server on Ubuntu WSL
    - `sudo apt-get install openssh-server`
- Change WSL Ubuntu's SSH port to something other than the default 22 otherwise it will conflict with Windows' own SSH server which runs if developer mode is enabled.
    - `sudo nano /etc/ssh/sshd_config`: Open SSH server config file in `nano` editor.
    - Change `#Port 22` to `Port 2222` (or whatever port you want)
    - `sudo service ssh restart`
    - ⚠️ **Remember this port**. You will need to use this port when connecting to WSL Ubuntu from Windows.
- Install "Remote - SSH" VSCode extension to run VSCode inside WSL & open a VSCode SSH session into WSL.
- Setup Windows SSH configuration file to add Ubuntu WSL as a SSH host.
    - After installing "Remote - SSH" in VSCode, search for "Remote-SSH: Open Configuration File..." in the command palette.
    - Use the config file located in `C:\Users\<username>\.ssh\config` (or create it if it doesn't exist)
    - Inside it, write this:
        ```
        Host <name>
            HostName localhost
            Port <port>
            User <username>
        ```
        - Replace `<name>` with whatever you want to call the host (e.g. WSL_Ubuntu). Don't use spaces.
        - Replace `<port>` with the port you just set in the SSH server config file (e.g. 2222)
        - Replace `<username>` with your Ubuntu WSL username you configured (which may not be the same as your Windows username!)
- 🟢 **In order to not have to type Ubuntu password every connection:**
    - On Windows, create an SSH keypair using `openssl` if you don't already have one. [GitHub's guide on how to create/check for existing SSH keys](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account?platform=windows)
        - After generating, you should find a public key like `~/.ssh/id_ed25519.pub` inside your user directory.
        - Open the `.pub` file with Notepad & copy the contents (that will be one of your device's public key)
    - Now in Ubuntu, paste public key into `~/.ssh/authorized_keys` on a new line. Create the file if it doesn't already exist.
    - `eval $(ssh-agent)`: Start ssh-agent
    - `ssh-add`: Add authorized keys'
    - `sudo service ssh restart`: Restart SSH server
- Install homebrew in WSL Ubuntu (linuxbrew)
    - `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`
    - Make sure to follow the **'Next steps:'** instructions after the script runs.
        - It will ask you to `sudo apt-get install build-essential gcc` if you don't have those packages already, which you should do.
        - Ensure that `~/.profile` contains the line `eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"`, otherwise the `brew` command & shell enviroment won't be available.
    - Run `source ~/.profile` to update changes on your current terminal session (or just re-login/restart Ubuntu)
- Install ruby with brew on WSL Ubuntu
    - `brew install ruby-install`
    - Check command works: `ruby-install -V`
    - Install ruby: `ruby-install ruby 3.2.2` (or whatever version Sonic Pi is using now)
- Install chruby with brew on WSL Ubuntu
    - `brew install chruby`
    - ⚠️ **NOTE:** Because it is installed with brew, chruby will be located in `/home/linuxbrew/.linuxbrew/opt/chruby/share/chruby`, instead of `/usr/local/share/chruby`.
    - Add chruby to `~/.bashrc`:
        - `source /home/linuxbrew/.linuxbrew/opt/chruby/share/chruby/chruby.sh`
        - To enable auto context switching based on a `.ruby-version` file in the current directory, also add:
        `source /home/linuxbrew/.linuxbrew/opt/chruby/share/chruby/auto.sh`
    - Run `source ~/.bashrc` to update changes (or open a new terminal session)
- Clone this repository in Ubuntu and run `bundle install` to install ruby dependencies.
- For the vscode-ruby-lsp extension to work:
    - `cd /path/to/project`.
        - ⚠️ The project's chruby environment must be activated so that the ruby-lsp install will be located at the right place.
    - `gem install ruby-lsp`.
        - With chruby active, this should install into `~/.gem/ruby/3.2.2/bin/ruby-lsp`
        - Make sure you can run `ruby-lsp` from the terminal without error.
- For Solargraph VSCode extension to work:
    - `cd ~`: **Exit project directory**. Don't install the solargraph gem in the project's chruby 'sandbox' environment, as it doesn't seem to work in VSCode.
    - `gem install solargraph'
    - Make sure you can run `solargraph` from the terminal without error.
    - This solargraph should be installed in `/usr/local/bin/solargraph`.

## Notes to self

Referencing Sonic Pi's "global-scope context" inside classes requires using the `$GLO` prefix defined in [prelude_for_livecoding.rb](/prelude_for_livecoding.rb) as Sonic Pi's global context is different from the scope which classes are defined in (which are actually default Ruby global scope).

The project repo is structured like a Gem for organization purposes & better support with extensions/linters/lsp/plugins, but it's not meant to ship as one.

Ruby dev on windows is cursed.
