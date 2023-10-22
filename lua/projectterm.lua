-- ~/.config/nvim/lua/myfunctions.lua

local Terminal  = require('toggleterm.terminal').Terminal
local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local conf = require("telescope.config").values
local actions = require "telescope.actions"
local action_state = require "telescope.actions.state"
local null_output_bufnr = -9999
local debug_buffer_name = "ProjectTerm debug"

local function get_project_root()
  return vim.fn.system("git rev-parse --show-toplevel"):gsub("\n", "")
end

local function get_buffer_from_name(buffer_name)
  local output_bufnr = null_output_bufnr
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_name(buf) == get_project_root() .. "/" .. buffer_name then
      output_bufnr = buf
      break
    end
  end
  if output_bufnr == null_output_bufnr then
    output_bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(output_bufnr, 0, -1, false, {})
    vim.api.nvim_buf_set_name(output_bufnr, buffer_name)
  end
  return output_bufnr
end

local function clear_debug_buffer()
  local bufnr = get_buffer_from_name(debug_buffer_name)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
end

local function print_debug(text)
  local bufnr = get_buffer_from_name(debug_buffer_name)
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  vim.api.nvim_buf_set_lines(bufnr, line_count, line_count, false, {text})
end

local function ensure_file_exists(filepath)
  if vim.fn.filereadable(filepath) == 0 then
    local file = io.open(filepath, "w")
    if file ~= nil then
      file:close()
    end
  end
end

-- Will be used for coloring output.
local function split_string(inputstr)
  local sep = "----"
  local t = {}
  for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
    str = str:gsub("%s+", "")
    str = string.gsub(str, "%s+", "")
    if str == "plus" then
      str = "#ff0000"
    elseif str == "minus" then
      str = "#000ff0"
    end
    table.insert(t, str)
  end
  return t
end

local function get_build_commands(filepath)
  local lines = {}
  local file = io.open(filepath, "r")
  if not file then
    return nil, "Failed to open file."
  end
  for line in file:lines() do
    table.insert(lines, line)
  end
  file:close()
  return lines
end

local function remove_terminal_process_exited_msg(bufnr)
  local pattern = "%[Process exited %-?%d+%]"
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local filtered_lines = {}
  for _, line in ipairs(lines) do
    if not string.match(line, pattern) then
      table.insert(filtered_lines, line)
    end
  end
  vim.api.nvim_buf_set_option(bufnr, 'modifiable', true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, filtered_lines)
end

local function command_exists_in_commands(cmd, commands_text)
  for target_line in commands_text:gmatch("[^\r\n]+") do
    if target_line == cmd then
      return true
    end
  end
  return false
end

local function ensure_cmd_in_commands_file(filename, cmd)
  local f = io.open(filename, "r")
  if not f then
    print_debug("Failed to open file for reading: " .. filename)
    return
  end
  local content = f:read("*all")
  f:close()
  if command_exists_in_commands(cmd, content) then
    print_debug("Command known, saving to commands file skipped.")
    return
  end
  content = cmd .. "\n" .. content
  f = io.open(filename, "w")
  if not f then
    print_debug("Failed to open file for writing: " .. filename)
    return
  end
  f:write(content)
  print_debug("Saved command '" .. cmd .. "' to commands file '" .. filename .. "'.")
  f:close()
end

local function handle_exit(prompt_bufnr, savefile, use_current_line)
  print_debug("Handling picker exit...")
  local cmd = ""
  print(vim.inspect(action_state.get_current_history()))
  if use_current_line or action_state.get_selected_entry() == nil then
    cmd = action_state.get_current_line()
    print_debug("Using current line: '" .. cmd .. "'.")
  else
    cmd = action_state.get_selected_entry().value[1]
    print_debug("Using selection: '" .. cmd .. "'.")
  end
  ensure_cmd_in_commands_file(savefile, cmd)
  actions.close(prompt_bufnr)
  Terminal:new({
    cmd = cmd,
    dir = get_project_root(),
    hidden = false,
    shading_factor = '90',
    close_on_exit = false,
    direction = 'horizontal',
    size = 25,
    on_open = function(term)
      vim.cmd("startinsert!")
      vim.api.nvim_buf_set_keymap(term.bufnr, "n", "q", "<cmd>close<CR>", {noremap = true, silent = true})
    end,
    on_close = function(term)
      -- FIXME: This isn't currently working for some reason
      remove_terminal_process_exited_msg(term.bufnr)
    end,
    on_exit = function(term, _, exit_code, _)
      local msg = ""
      if exit_code == 0 then
        local buffer_name = "ProjectTerm output"
        local output_bufnr = get_buffer_from_name(buffer_name)
        local content = vim.api.nvim_buf_get_lines(term.bufnr, 0, -1, false)
        vim.api.nvim_buf_set_lines(output_bufnr, 0, -1, false, content)
        if not keep_alive then
          vim.cmd("bdelete " .. term.bufnr)
        end
        msg = "ProjectTerm execution successful. Process output written to buffer *ProjectTerm output*."
      else
        msg = "ProjectTerm execution failed with exit code " .. exit_code .. "."
      end
      print(msg .. " Debug logs written to buffer *" .. debug_buffer_name .. "*.")
    end,
  }):toggle()
end

local function show_custom_picker(lines, opts, savefile)
  pickers.new(opts, {
    prompt_title = "ProjectTerm Search Comands",
    finder = finders.new_table {
      results = lines,
      entry_maker = function(entry)
        return {
          value = { entry, "#ff0000" },
          ordinal = entry,
          display = entry,
        }
      end
    },
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(_, map) -- Ensure you use the correct function name
      map('i', '<CR>', function (prompt_bufnr) handle_exit(prompt_bufnr, savefile) end)
      map('n', '<CR>', function (prompt_bufnr) handle_exit(prompt_bufnr, savefile) end)
      map('n', '<leader>\\', function (prompt_bufnr) handle_exit(prompt_bufnr, savefile, true) end)
      map('n', 'gf', function () 
        print_debug("called gf")
        vim.cmd('wincmd p')
      end)
      return true -- Let Telescope continue attaching other mappings as well
    end,
  }):find()
end

function ProjectTerm(_)
  clear_debug_buffer()
  local commands_file = get_project_root() .. "/.projectterm_commands"
  print_debug("Running projectterm() from '" .. commands_file .. "'")
  ensure_file_exists(commands_file)
  local lines = get_build_commands(commands_file)
  local opts = require("telescope.themes").get_dropdown{}
  show_custom_picker(lines, opts, commands_file)
end

local M = {}

M.projectterm = ProjectTerm

vim.cmd("command! ProjectTerm lua ProjectTerm()")

return M
