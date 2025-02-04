local function percentile(sorted_data, percent)
	local n = #sorted_data
	if n == 0 then
		return nil
	end -- Handle empty data case
	if n == 1 then
		return sorted_data[1]
	end -- Single value case

	local index = (percent / 100) * (n - 1) + 1 -- Adjust index to avoid 0

	local lower_idx = math.floor(index)
	local upper_idx = math.ceil(index)

	-- Ensure indices stay within bounds
	if lower_idx < 1 then
		lower_idx = 1
	end
	if upper_idx > n then
		upper_idx = n
	end

	if lower_idx == upper_idx then
		return sorted_data[lower_idx]
	else
		local lower = sorted_data[lower_idx]
		local upper = sorted_data[upper_idx]
		return lower + (upper - lower) * (index - lower_idx)
	end
end

local function benchmark_stats(times)
	if #times == 0 then
		return nil
	end -- Handle empty array case

	-- Compute average
	local sum = 0
	for _, time in ipairs(times) do
		sum = sum + time
	end
	local avg = sum / #times

	-- Compute percentiles
	return {
		avg = avg,
		p10 = percentile(times, 10),
		p50 = percentile(times, 50), -- Median
		p90 = percentile(times, 90),
		p1 = percentile(times, 1),
		p99 = percentile(times, 99)
	}
end

return function<T...>(label: string, f: (T...) -> any, times: number, ...: T)
	local averages = {}

	for _ = 1, times do
		local start = os.clock()
		f(...)
		local ended = os.clock()

		table.insert(averages, ended - start)
	end

	table.sort(averages, function(a,b)
		return b > a
	end)

	local stats = benchmark_stats(averages)
	print(`Benched {label} {times} times, results:`)
	print(`  Average: {stats.avg}s`)
	print(`  Best: {stats.p1}`)
	print(`  10th percentile: {stats.p10}s`)
	print(`  50th percentile: {stats.p50}s`)
	print(`  90th percentile: {stats.p90}s`)
	print(`  Worst: {stats.p99}`)
end
