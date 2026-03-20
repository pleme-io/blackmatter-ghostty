# graphics/serialize.nix
# Serialize a Ghostty settings attrset to the raw config text format.
#
# Ghostty uses `key = value` pairs, one per line. Lists produce
# repeated keys (e.g. `palette = 0=...`, `palette = 1=...`).
# Booleans serialize as "true"/"false".
{ lib }:
let
  # Serialize a single value to string.
  valueToStr = v:
    if builtins.isBool v then (if v then "true" else "false")
    else if builtins.isInt v then toString v
    else if builtins.isFloat v then toString v
    else if builtins.isString v then v
    else toString v;

  # Serialize one key-value pair to config lines.
  # Lists produce one line per element with the same key.
  pairToLines = k: v:
    if builtins.isList v then
      map (elem: "${k} = ${valueToStr elem}") v
    else
      [ "${k} = ${valueToStr v}" ];

  # Serialize an entire settings attrset to config text.
  # Filters out null values. Sorts keys for deterministic output.
  settingsToText = settings:
    let
      filtered = lib.filterAttrs (_: v: v != null) settings;
      keys = builtins.sort builtins.lessThan (builtins.attrNames filtered);
      lines = builtins.concatMap (k: pairToLines k filtered.${k}) keys;
    in
      builtins.concatStringsSep "\n" lines;

in {
  inherit settingsToText valueToStr;
}
