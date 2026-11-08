local user_bin = os.getenv("HOME") .. "/.config/omarchy/bin"
local path_parts = {}
local seen_dirs = { [user_bin] = true }
path_parts[#path_parts + 1] = user_bin
for dir in (os.getenv("PATH") or "/usr/bin"):gmatch("[^:]+") do
  if dir ~= "" and not seen_dirs[dir] then
    seen_dirs[dir] = true
    path_parts[#path_parts + 1] = dir
  end
end
hl.env("PATH", table.concat(path_parts, ":"))
hl.env("OMARCHY_MENU_FONT", "Outfit")
hl.env("HYPRCURSOR_THEME", "nightcity")
hl.env("HYPRCURSOR_SIZE", "32")
hl.env("XCURSOR_THEME", "nightcity")
hl.env("XCURSOR_SIZE", "32")
