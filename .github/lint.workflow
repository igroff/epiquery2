workflow "lint" {
  on = "push"
  resolves = "lint"
}

action "lint" {
  uses = "fearphage/actions/shellcheck@shellcheck"
}
