---@alias StringRange { start: integer, end_: integer }
---@alias Error
---| { full: StringRange, filename: { value: string, range: StringRange }, row: { value: integer, range: StringRange }?, col: { value: integer, range: StringRange }? }

-- local function print_range(input, range)
-- 	if range ~= nil then
-- 		print(input)
-- 		print(string.rep(" ", range[1] - 1) .. string.rep("^", range[2] - range[1] + 1))
-- 	end
-- end

local M = {}

---@type table<integer, Error>
M.error_list = {}

---TODO: document
---(REGEXP FILE [LINE COLUMN TYPE HYPERLINK HIGHLIGHT...])
---@type table<string, { [1]: string, [2]: integer, [3]: integer|IntByInt|nil, [4]: integer|IntByInt|nil, [5]: nil|0|1|2 }>
M.error_regexp_table = {
	-- TODO: use the actual alist from Emacs
	gnu = {
		"^\\%([[:alpha:]][-[:alnum:].]\\+: \\?\\|[ 	]\\%(in \\| from\\)\\)\\?\\(\\%([0-9]*[^0-9\\n]\\)\\%([^\\n :]\\| [^-/\\n]\\|:[^ \\n]\\)\\{-}\\)\\%(: \\?\\)\\([0-9]\\+\\)\\%(-\\([0-9]\\+\\)\\%(\\.\\([0-9]\\+\\)\\)\\?\\|[.:]\\([0-9]\\+\\)\\%(-\\%(\\([0-9]\\+\\)\\.\\)\\([0-9]\\+\\)\\)\\?\\)\\?:\\%( *\\(\\%(FutureWarning\\|RuntimeWarning\\|W\\%(arning\\)\\|warning\\)\\)\\| *\\([Ii]nfo\\%(\\>\\|formationa\\?l\\?\\)\\|I:\\|\\[ skipping .\\+ ]\\|instantiated from\\|required from\\|[Nn]ote\\)\\| *\\%([Ee]rror\\)\\|\\%([0-9]\\?\\)\\%([^0-9\\n]\\|$\\)\\|[0-9][0-9][0-9]\\)",
		1,
		{ 2, 4 },
		{ 3, 5 },
		-- TODO: implement this
		nil,
	},
}

---TODO: this should be more flexible
---Given a `matchlistpos` result and a capture-group matcher, return the relevant capture group.
---
---@param result (StringRange|nil)[]
---@param group integer|IntByInt|nil
---@return StringRange|nil
local function parse_matcher_group(result, group)
	if not group then
		return nil
	elseif type(group) == "number" then
		return result[group + 1] ~= nil and result[group + 1] or nil
	elseif type(group) == "table" then
		local first = group[1] + 1
		local second = group[2] + 1

		if result[first] and result[first] ~= "" then
			return result[first]
		elseif result[second] and result[second] ~= "" then
			return result[second]
		else
			return nil
		end
	end
end

---@param input string
---@param pattern string
---@return (StringRange|nil)[]
local function matchlistpos(input, pattern)
	local list = vim.fn.matchlist(input, pattern) --[[@as string[] ]]

	---@type (IntByInt|nil)[]
	local result = {}

	local latest_index = vim.fn.match(input, pattern)
	for i, capture in ipairs(list) do
		if capture == "" then
			result[i] = nil
		else
			local start, end_ = string.find(input, capture, latest_index, true)
			assert(start and end_)
			if i ~= 1 then
				latest_index = end_ + 1
			end
			result[i] = {
				start = start,
				end_ = end_,
			}
		end
	end

	return result
end

local function parse_matcher(matcher, line)
	local regex = matcher[1]
	local result = matchlistpos(line, regex)
	if not result then
		return nil
	end

	local filename_range = result[matcher[2] + 1]
	if not filename_range then
		return nil
	end

	local row_range = parse_matcher_group(result, matcher[3])
	local col_range = parse_matcher_group(result, matcher[4])

	---@type Error
	return {
		full = result[1],
		filename = {
			value = line:sub(filename_range.start, filename_range.end_),
			range = filename_range,
		},
		row = row_range and {
			value = tonumber(line:sub(row_range.start, row_range.end_)),
			range = row_range,
		} or nil,
		col = col_range and {
			value = tonumber(line:sub(col_range.start, col_range.end_)),
			range = col_range,
		},
	}
end

---Parses error syntax from a given line.
---@param line string the line to parse
---@return Error|nil
function M.parse(line)
	for _, matcher in pairs(M.error_regexp_table) do
		local result = parse_matcher(matcher, line)
		if result then
			return result
		end
	end

	return nil
end

return M
