local M = {}

local ESC_FEEDKEY = vim.api.nvim_replace_termcodes("<ESC>", true, false, true)

function M.split(text)
  local t = {}
  for str in string.gmatch(text, "%S+") do
    table.insert(t, str)
  end
  return t
end

function M.split_string_by_line(text)
  local lines = {}
  for line in (text .. "\n"):gmatch("(.-)\n") do
    table.insert(lines, line)
  end
  return lines
end

function M.max_line_length(lines)
  local max_length = 0
  for _, line in ipairs(lines) do
    local str_length = string.len(line)
    if str_length > max_length then
      max_length = str_length
    end
  end
  return max_length
end

function M.wrapText(text, maxLineLength)
  local lines = M.wrapTextToTable(text, maxLineLength)
  return table.concat(lines, "\n")
end

function M.trimText(text, maxLength)
  if #text > maxLength then
    return string.sub(text, 1, maxLength - 3) .. "..."
  else
    return text
  end
end

function M.wrapTextToTable(text, maxLineLength)
  local lines = {}

  local textByLines = M.split_string_by_line(text)
  for _, line in ipairs(textByLines) do
    if #line > maxLineLength then
      local tmp_line = ""
      local words = M.split(line)
      for _, word in ipairs(words) do
        if #tmp_line + #word + 1 > maxLineLength then
          table.insert(lines, tmp_line)
          tmp_line = word
        else
          tmp_line = tmp_line .. " " .. word
        end
      end
      table.insert(lines, tmp_line)
    else
      table.insert(lines, line)
    end
  end
  return lines
end

local function bit_and(a, b)
  local res = 0
  local bi = 1
  while a > 0 and b > 0 do
    if a % 2 == 1 and b % 2 == 1 then
      res = res + bi
    end
    a = math.floor(a / 2)
    b = math.floor(b / 2)
    bi = bi * 2
  end
  return res
end


local function utf8_parse(s)
  local cs = {}
  local i = 1
  while i <= #s do
    local c = string.byte(s:sub(i, i))
    if bit_and(c, 0b11111100) == 0b11111100 then
      table.insert(cs, {
        s = s:sub(i, i + 5),
        n = 6,
      })
      i = i + 6;
    elseif bit_and(c, 0b11111000) == 0b11111000 then
      table.insert(cs, {
        s = s:sub(i, i + 4),
        n = 5,
      })
      i = i + 5;
    elseif bit_and(c, 0b11110000) == 0b11110000 then
      table.insert(cs, {
        s = s:sub(i, i + 3),
        n = 4,
      })
      i = i + 4;
    elseif bit_and(c, 0b11100000) == 0b11100000 then
      table.insert(cs, {
        s = s:sub(i, i + 2),
        n = 3,
      })
      i = i + 3;
    elseif bit_and(c, 0b11000000) == 0b11000000 then
      table.insert(cs, {
        s = s:sub(i, i + 1),
        n = 2,
      })
      i = i + 2;
    else
      table.insert(cs, {
        s = s:sub(i, i),
        n = 1,
      })
      i = i + 1;
    end
  end
  return cs
end

local function utf8_char_end_col(s, col)
  local cs = utf8_parse(s)
  local idx = 1 -- cs的索引
  local pos = 0 -- 下次要检查的字符开始
  while pos <= col and idx <= #cs do
    pos = pos + cs[idx].n
    idx = idx + 1
  end
  return pos - 1
end

function M.get_visual_lines(bufnr)
  vim.api.nvim_feedkeys(ESC_FEEDKEY, "n", true)
  vim.api.nvim_feedkeys("gv", "x", false)
  vim.api.nvim_feedkeys(ESC_FEEDKEY, "n", true)

  bufnr = bufnr or 0
  local start_row, start_col = unpack(vim.api.nvim_buf_get_mark(bufnr, "<"))
  local end_row, end_col = unpack(vim.api.nvim_buf_get_mark(bufnr, ">"))
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_row - 1, end_row, false)

  -- get whole buffer if there is no current/previous visual selection
  if start_row == 0 then
    lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    start_row = 1
    start_col = 0
    end_row = #lines
    end_col = #lines[#lines]
  end

  -- get the specified buffer code
  local encoding = vim.api.nvim_buf_get_option(bufnr, 'fileencoding')
  -- convert to lua index
  local start_col_idx = start_col + 1
  local end_col_idx = end_col + 1
  if encoding == "utf-8" then
    end_col_idx = utf8_char_end_col(lines[#lines], end_col) + 1
  end

  -- process selections
  if start_row == end_row then
    lines[1] = lines[1]:sub(start_col_idx, end_col_idx)
  else
    lines[1] = lines[1]:sub(start_col_idx)
    lines[#lines] = lines[#lines]:sub(1, end_col_idx)
  end

  return lines, start_row, start_col_idx, end_row, end_col_idx
end

function M.count_newlines_at_end(str)
  local start, stop = str:find("\n*$")
  return (stop - start + 1) or 0
end

function M.replace_newlines_at_end(str, num)
  local res = str:gsub("\n*$", string.rep("\n", num), 1)
  return res
end

function M.change_mode_to_normal()
  vim.api.nvim_feedkeys(ESC_FEEDKEY, "n", false)
end

function M.change_mode_to_insert()
  vim.api.nvim_command("startinsert")
end

function M.calculate_percentage_width(percentage)
  -- Check that the input is a string and ends with a percent sign
  if type(percentage) ~= "string" or not percentage:match("%%$") then
    error("Input must be a string with a percent sign at the end (e.g. '50%').")
  end

  -- Remove the percent sign from the string
  local percent = tonumber(string.sub(percentage, 1, -2))
  local editor_width = vim.api.nvim_get_option("columns")

  -- Calculate the percentage of the width
  local width = math.floor(editor_width * (percent / 100))
  -- Return the calculated width
  return width
end

return M
