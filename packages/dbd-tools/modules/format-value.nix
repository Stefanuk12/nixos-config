# Render a Nix value to its UE-ini string form; `context` prefixes the error thrown on an unsupported type.
context: v:
if builtins.isBool v then
  (if v then "True" else "False")
else if builtins.isInt v then
  toString v
else if builtins.isFloat v then
  toString v
else if builtins.isString v then
  v
else
  throw "${context}: unsupported value type for ${builtins.toJSON v}"
