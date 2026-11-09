# Basalt's shell, part one: history, oh-my-zsh (no theme: starship draws the
# prompt), its git, sudo and starship plugins, autosuggestions, and the aliases.
#
# USING IT. A host's interactive rc sources this, adds its own lines, then
# sources finish.zsh, which has to come last:
#
#   source ~/.config/zsh/basalt/init.zsh
#   # ... the host's own: PATH, tools, aliases, ~/.zshrc.local
#   source ~/.config/zsh/basalt/finish.zsh
#
# Where things live differs per machine, so a host may set these first; each
# default is the usual place on a distribution that packages them:
#
#   BASALT_OMZ               oh-my-zsh's directory         (~/.oh-my-zsh)
#   BASALT_ZSH_AUTOSUGGEST   zsh-autosuggestions.zsh       (/usr/share/zsh-autosuggestions/…)
#   BASALT_ZSH_HIGHLIGHT     zsh-syntax-highlighting.zsh   (/usr/share/zsh-syntax-highlighting/…)
#
# A plugin that is not there is skipped, not an error. The Nix module sets all
# three to store paths.

# ---- history ----
HISTFILE=$HOME/.zsh_history
HISTSIZE=2000
SAVEHIST=2000
setopt HIST_IGNORE_DUPS SHARE_HISTORY HIST_FCNTL_LOCK

# ---- autosuggestions: grey, from history ----
: ${BASALT_ZSH_AUTOSUGGEST:=/usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh}
if [[ -r $BASALT_ZSH_AUTOSUGGEST ]]; then
  source "$BASALT_ZSH_AUTOSUGGEST"
  ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=8"
  ZSH_AUTOSUGGEST_STRATEGY=(history)
fi

# ---- oh-my-zsh ----
: ${BASALT_OMZ:=$HOME/.oh-my-zsh}
if [[ -r $BASALT_OMZ/oh-my-zsh.sh ]]; then
  export ZSH=$BASALT_OMZ
  ZSH_THEME=""  # empty: the prompt comes from starship, not an omz theme
  ZSH_CACHE_DIR=$HOME/.cache/oh-my-zsh
  [[ -d $ZSH_CACHE_DIR ]] || mkdir -p "$ZSH_CACHE_DIR"
  plugins=(git sudo starship)
  source "$ZSH/oh-my-zsh.sh"
fi

# ---- pager ----
# less quits by itself when the output fits on one screen, so a short `git diff`
# just prints. Git asks for this (LESS=FRX) only when LESS is unset, and
# oh-my-zsh sets it to -R, so it is set here, after oh-my-zsh.
export LESS=-FR

# ---- aliases ----
alias l='ls -alh'
alias ll='ls -l'
