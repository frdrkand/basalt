# Basalt's shell, part two: syntax highlighting. It wraps every line-editor
# widget defined before it, so it is sourced last, after init.zsh and everything
# the host adds. See init.zsh for BASALT_ZSH_HIGHLIGHT.
: ${BASALT_ZSH_HIGHLIGHT:=/usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh}
if [[ -r $BASALT_ZSH_HIGHLIGHT ]]; then
  source "$BASALT_ZSH_HIGHLIGHT"
  ZSH_HIGHLIGHT_HIGHLIGHTERS=(main)
fi
