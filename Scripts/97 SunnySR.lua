-- Sunny Rebirth SR for VSRG charts, ported from Dan-Overlay's vendored
-- src/03_engine_reference/sr_core/algorithm.py. Input times are integer ms
-- already transformed by getISORChartData for the selected playback rate.
HV = HV or {}

local function lowerBound(a, x)
	local lo, hi = 1, #a + 1
	while lo < hi do
		local mid = math.floor((lo + hi) / 2)
		if a[mid] < x then lo = mid + 1 else hi = mid end
	end
	return lo
end

local function uniqueSorted(set)
	local a = {}
	for _,v in pairs(set) do a[#a + 1] = v end
	table.sort(a)
	return a
end

local function cornersFor(events, T, offsets)
	local set = {[0] = 0, [T] = T}
	for _,e in ipairs(events) do
		for _,d in ipairs(offsets) do
			local v = e.time + d
			if v >= 0 and v <= T then set[v] = v end
		end
	end
	return uniqueSorted(set)
end

-- Integrate the piecewise-constant values over [t-window,t+window].
local function smooth(x, f, window, mode)
	local n = #x
	if n < 2 then return f end
	local prefix = {0}
	for i = 1, n - 1 do prefix[i + 1] = prefix[i] + f[i] * (x[i + 1] - x[i]) end
	local function integral(q)
		if q <= x[1] then return 0 end
		if q >= x[n] then return prefix[n] end
		local i = math.max(1, lowerBound(x, q) - 1)
		return prefix[i] + f[i] * (q - x[i])
	end
	local out = {}
	for i = 1, n do
		local a, b = math.max(x[1], x[i] - window), math.min(x[n], x[i] + window)
		local v = integral(b) - integral(a)
		out[i] = mode == "avg" and (b > a and v / (b - a) or 0) or v * 0.001
	end
	return out
end

local function interp(x, y, xx)
	local out = {}
	for i,v in ipairs(xx) do
		local j = lowerBound(x, v)
		if j <= 1 then out[i] = y[1]
		elseif j > #x then out[i] = y[#y]
		else
			local t = (v - x[j - 1]) / math.max(x[j] - x[j - 1], 1e-9)
			out[i] = y[j - 1] + (y[j] - y[j - 1]) * t
		end
	end
	return out
end

local function stepInterp(x, y, xx)
	local out = {}
	for i,v in ipairs(xx) do out[i] = y[math.max(1, math.min(#y, lowerBound(x, v + 1e-9) - 1))] end
	return out
end

function HV.CalculateSunnySR(events, keyCount)
	if type(events) ~= "table" or tonumber(keyCount) ~= 4 or #events < 2 then return nil end
	local notes, byKey, maxTime = {}, {{}, {}, {}, {}}, 0
	for _,e in ipairs(events) do
		local t, k = tonumber(e.time), tonumber(e.column)
		if t and k and k >= 1 and k <= 4 then
			local note = {k = k - 1, h = t}
			notes[#notes + 1] = note
			byKey[k][#byKey[k] + 1] = note
			maxTime = math.max(maxTime, t)
		end
	end
	if #notes < 2 then return nil end
	table.sort(notes, function(a,b) if a.h == b.h then return a.k < b.k end return a.h < b.h end)
	local T = maxTime + 1
	local od = 9
	local x = 0.3 * math.sqrt((64.5 - math.ceil(od * 3)) / 500)
	x = math.min(x, 0.6 * (x - 0.09) + 0.09)
	local base = cornersFor(events, T, {0, 501, -499, 1})
	local ac = cornersFor(events, T, {0, 1000, -1000})
	local allSet = {}; for _,v in ipairs(base) do allSet[v] = v end; for _,v in ipairs(ac) do allSet[v] = v end
	local all = uniqueSorted(allSet)
	if #all < 2 then return nil end
	local n, nb, na = #all, #base, #ac
	local usage, use400 = {}, {}
	for k = 1, 4 do
		usage[k], use400[k] = {}, {}
		for i = 1, nb do usage[k][i], use400[k][i] = 0, 0 end
		for _,e in ipairs(byKey[k]) do
			local l = lowerBound(base, math.max(0,e.h-150))
			local r = lowerBound(base, math.min(T-1,e.h+150))
			for i=l,r-1 do usage[k][i] = 1 end
			l, r = lowerBound(base, e.h-400), lowerBound(base, e.h+400)
			for i=l,r-1 do local d=base[i]-e.h; use400[k][i]=use400[k][i]+3.75-(3.75/160000)*d*d end
		end
	end
	local active = {}
	for i = 1, nb do active[i] = {}; for k = 1, 4 do if usage[k][i] > 0 then active[i][#active[i] + 1] = k - 1 end end end
	local anchor = {}
	for i = 1, nb do
		local c = {use400[1][i], use400[2][i], use400[3][i], use400[4][i]}; table.sort(c, function(a,b) return a > b end)
		local walk, maxWalk = 0, 0
		for j = 1, 3 do if c[j] > 0 and c[j+1] > 0 then local r = c[j+1]/c[j]; walk = walk + c[j] * (1 - 4*(0.5-r)^2); maxWalk = maxWalk + c[j] end end
		local raw = maxWalk > 0 and walk / maxWalk or 0
		anchor[i] = 1 + math.min(raw - 0.18, 5 * (raw - 0.22)^3)
	end
	local delta, jRaw = {}, {}
	for k = 1, 4 do
		delta[k], jRaw[k] = {}, {}
		for i = 1, nb do delta[k][i], jRaw[k][i] = 1e9, 0 end
		local ts = byKey[k]
		for q = 2, #ts do
			local a, b = ts[q-1].h, ts[q].h; local d = (b-a)/1000
			if d > 0 then
				local val = d^-1 * (d + 0.11*x^0.25)^-1 * (1 - 7e-5*(0.15+math.abs(d-0.08))^-4)
				local l, r = lowerBound(base, a), lowerBound(base, b)
				for i = l, r-1 do delta[k][i], jRaw[k][i] = d, val end
			end
		end
	end
	local jSmooth = {}
	for k = 1, 4 do jSmooth[k] = smooth(base, jRaw[k], 500, "sum") end
	local J, jMax = {}, 0
	for i = 1, nb do
		local num, den = 0, 0
		for k = 1, 4 do local w = 1/delta[k][i]; num = num + math.max(jSmooth[k][i],0)^5*w; den = den+w end
		J[i] = (num/math.max(den,1e-9))^0.2; jMax = math.max(jMax, J[i])
	end
	local cross = {0.175,0.25,0.05,0.25,0.175}
	local Xparts, Fcparts = {}, {}
	for pair = 0, 4 do
		Xparts[pair+1], Fcparts[pair+1] = {}, {}
		for i = 1, nb do Xparts[pair+1][i], Fcparts[pair+1][i] = 0, 0 end
		local seq = {}
		if pair == 0 then seq = byKey[1]
		elseif pair == 4 then seq = byKey[4]
		else
			for _,e in ipairs(byKey[pair]) do seq[#seq+1]=e end; for _,e in ipairs(byKey[pair+1]) do seq[#seq+1]=e end
			table.sort(seq,function(a,b) return a.h < b.h end)
		end
		for q=2,#seq do
			local a,b=seq[q-1].h,seq[q].h; local d=(b-a)/1000
			if d>0 then
				local val=0.16*math.max(x,d)^-2
				local fc=math.max(0,0.4*math.max(d,math.max(0.06,0.75*x))^-2-80)
				local l,r=lowerBound(base,a),lowerBound(base,b)
				local function hasColumn(index, col)
					if index < 1 or index > nb then return false end
					for _,v in ipairs(active[index]) do if v == col then return true end end
					return false
				end
				for i=l,r-1 do
					local leftInactive = not hasColumn(l, pair-1) and not hasColumn(r, pair-1)
					local rightInactive = not hasColumn(l, pair) and not hasColumn(r, pair)
					local adjusted = (leftInactive or rightInactive) and val*(1-cross[pair+1]) or val
					Xparts[pair+1][i],Fcparts[pair+1][i]=adjusted,fc
				end
			end
		end
	end
	local Xraw, Praw = {}, {}
	for i=1,nb do
		local v=0
		for p=1,5 do v=v+Xparts[p][i]*cross[p] end
		for p=1,4 do v=v+math.sqrt(Fcparts[p][i]*cross[p]*Fcparts[p+1][i]*cross[p+1]) end
		Xraw[i],Praw[i]=v,0
	end
	for q=2,#notes do
		local a,b=notes[q-1].h,notes[q].h; local dt=b-a; local l=lowerBound(base,a)
		if dt==0 then
			local ri=lowerBound(base,a+1e-9); local spike=1000*(0.02*(4/x-24))^0.25
			for i=l,ri-1 do Praw[i]=Praw[i]+spike end
		elseif dt>0 then
			local r=lowerBound(base,b); local d=dt/1000; local bpm=math.min(420,7.5/d)
			local booster=1+0.10/(1+math.exp(-0.06*(bpm-175)))
			if bpm>=200 and bpm<=350 then booster=booster+0.30*(1-math.exp(-0.02*(bpm-200))) end
			local baseInc=(0.08*x^-1*(1-24*x^-1*(x/6)^2))^0.25
			local inc
			if d<2*x/3 then inc=d^-1*(0.08*x^-1*(1-24*x^-1*(d-x/2)^2))^0.25*math.max(booster,1)
			else inc=d^-1*baseInc*math.max(booster,1) end
			for i=l,r-1 do Praw[i]=Praw[i]+math.min(inc*anchor[i],math.max(inc,inc*2-10)) end
		end
	end
	local P=smooth(base,Praw,500,"sum"); local X=smooth(base,Xraw,500,"sum")
	local Araw={}; for i=1,na do
		local bi=math.max(1,math.min(nb,lowerBound(base,ac[i])))
		local cols=active[bi]; local v=1
		for j=2,#cols do
			local k0,k1=cols[j-1]+1,cols[j]+1
			local diff=math.abs(delta[k0][bi]-delta[k1][bi])+0.4*math.max(0,math.max(delta[k0][bi],delta[k1][bi])-0.11)
			if diff<0.02 then v=v*math.min(0.75+0.5*math.max(delta[k0][bi],delta[k1][bi]),1)
			elseif diff<0.07 then v=v*math.min(0.65+5*diff+0.5*math.max(delta[k0][bi],delta[k1][bi]),1) end
		end
		Araw[i]=v
	end
	local A=smooth(ac,Araw,250,"avg")
	local C,Ks={},{}
	local countLeft,countRight=1,1
	for i,t in ipairs(base) do
		while countLeft<=#notes and notes[countLeft].h<t-500 do countLeft=countLeft+1 end
		if countRight<countLeft then countRight=countLeft end
		while countRight<=#notes and notes[countRight].h<t+500 do countRight=countRight+1 end
		local count=countRight-countLeft
		local used=0; for k=1,4 do used=used+usage[k][i] end
		C[i],Ks[i]=count,math.max(used,1)
	end
	local Ji,Pi,Xi,Ai,Ci,Ksi=interp(base,J,all),interp(base,P,all),interp(base,X,all),interp(ac,A,all),stepInterp(base,C,all),stepInterp(base,Ks,all)
	local D,weights={},{}; local d93,d83,weighted=0,0,0
	for i=1,n do
		local av=Ai[i]; local s=((0.4*(av^(3/Ksi[i])*math.min(Ji[i],8+0.85*Ji[i]))^1.5)+(0.6*(av^(2/3)*(0.8*Pi[i]))^1.5))^(2/3)
		local tech=(av^(3/Ksi[i])*Xi[i])/(Xi[i]+s+1)
		D[i]=2.7*math.sqrt(math.max(s,0))*math.max(tech,0)^1.5+s*0.27
		local gap
		if i==1 then gap=(all[2]-all[1])/2 elseif i==n then gap=(all[n]-all[n-1])/2 else gap=(all[i+1]-all[i-1])/2 end
		weights[i]=Ci[i]*gap
		weighted=weighted+D[i]^5*weights[i]
	end
	local order={}; for i=1,n do order[i]=i end; table.sort(order,function(a,b) return D[a]<D[b] end)
	local cum,total={},0; for _,i in ipairs(order) do total=total+weights[i]; cum[#cum+1]=total end
	if total<=0 then return nil end
	local function quantile(p)
		local target=p*total
		for j,v in ipairs(cum) do if v>=target then return D[order[j]] end end
		return D[order[n]]
	end
	d93=(quantile(0.945)+quantile(0.935)+quantile(0.925)+quantile(0.915))/4
	d83=(quantile(0.845)+quantile(0.835)+quantile(0.825)+quantile(0.815))/4
	local sr=(0.88*d93*0.25+0.94*d83*0.20+(weighted/total)^0.2*0.55)*(#notes/(#notes+60))
	if sr>9 then sr=9+(sr-9)/1.2 end
	sr=sr*0.975
	local pMax,xMax,aSum=0,0,0
	for i=1,nb do pMax=math.max(pMax,P[i]); xMax=math.max(xMax,X[i]) end
	for _,v in ipairs(A) do aSum=aSum+v end
	local function r4(v) return math.floor(v*10000+0.5)/10000 end
	return {sr=r4(sr),jbar_max=r4(jMax),pbar_max=r4(pMax),xbar_max=r4(xMax),abar_mean=r4(aSum/math.max(#A,1)),
		d93=0,d83=0,d_weighted_mean=0,note_count=#notes}
end

