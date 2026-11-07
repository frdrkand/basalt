# A host's ~/.zshrc: Basalt's shell around the host's own lines. Basalt's zsh/
# is linked (or copied) at ~/.config/zsh/basalt.

# Where oh-my-zsh and the plugins live here, if not the defaults init.zsh names.
# BASALT_OMZ=$HOME/.oh-my-zsh

source ~/.config/zsh/basalt/init.zsh

# ---- the host's own ----
[[ -r $HOME/.zshrc.local ]] && source "$HOME/.zshrc.local"

# Last, after everything that defines line-editor widgets.
source ~/.config/zsh/basalt/finish.zsh
