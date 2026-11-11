-- Native port of ISOR's biomechanical strain summaries used by the ridge
-- calibration. Inputs are event rows already transformed for the selected rate.
HV = HV or {}

local function bioClamp(x,a,b) return math.max(a,math.min(b,x)) end
local function bit(mask,c) return math.floor(mask/(2^c))%2 end
local function intersects(a,b) for c=0,3 do if bit(a,c)==1 and bit(b,c)==1 then return true end end; return false end
local function copyArray(a) local r={}; for i,v in ipairs(a) do r[i]=v end; return r end
local function gate(x,a,b) return b<=a and (x>=b and 1 or 0) or bioClamp((x-a)/(b-a),0,1) end
local function rate(dt,base,offset,power,cap) return math.min(cap,(base/math.max(16,dt+offset))^power) end
local function quantile(a,q)
	if #a==0 then return 0 end
	table.sort(a)
	local pos=(#a-1)*q+1; local lo=math.floor(pos); local hi=math.ceil(pos); local w=pos-lo
	return a[lo]*(1-w)+a[hi]*w
end
local function cv(a)
	if #a<2 then return 0 end
	local s,s2=0,0; for _,v in ipairs(a) do s=s+v; s2=s2+v*v end
	local m=s/#a; return m>1e-6 and math.sqrt(math.max(0,s2/#a-m*m))/m or 0
end
local function decay(s,v,dt,tau) return s*math.exp(-math.max(0,dt)/tau)+v end
local function invGate(x,a,b) return 1-gate(x,a,b) end

function HV.ISORBioFeatures(events)
	if type(events)~="table" or #events==0 then return nil end
	local parsed={}
	for _,e in ipairs(events) do
		local t,c=tonumber(e.time),tonumber(e.column)
		if t and c and c>=1 and c<=4 then parsed[#parsed+1]={t=t,c=c} end
	end
	table.sort(parsed,function(a,b) if a.t==b.t then return a.c<b.c end return a.t<b.t end)
	local rowMap, times={},{}
	for _,e in ipairs(parsed) do
		local t=e.t; local rowTime=times[#times]
		if rowTime and math.abs(t-rowTime)<=2 then rowMap[rowTime].cols[e.c]=true
		else rowMap[t]={t=t,cols={[e.c]=true}}; times[#times+1]=t end
	end
	local rows, colCount={}, {0,0,0,0}
	for _,t in ipairs(times) do
		local src=rowMap[t]; local mask,left,right=0,0,0; local size,lcount,rcount=0,0,0
		for c=1,4 do if src.cols[c] then
			mask=mask+2^(c-1); size=size+1; colCount[c]=colCount[c]+1
			if c<=2 then left=left+2^(c-1); lcount=lcount+1 else right=right+2^(c-1); rcount=rcount+1 end
		end end
		rows[#rows+1]={t=t,mask=mask,left=left,right=right,size=size,lcount=lcount,rcount=rcount}
	end
	if #rows==0 then return nil end
	local inactive,breaks=0,0
	for i=2,#rows do local d=rows[i].t-rows[i-1].t; if d>1000 then inactive=inactive+d-1000; breaks=breaks+1 end end
	local activeDuration=math.max(1,(rows[#rows].t-rows[1].t-inactive)/1000)
	local activity={active_duration_s=activeDuration,break_density=breaks/math.max(activeDuration/60,1),avg_nps=#rows/activeDuration}
	local windowSizes={250,500,1000,4000}; local starts={1,1,1,1}
	for i,r in ipairs(rows) do
		for w,width in ipairs(windowSizes) do
			while starts[w]<=i and rows[starts[w]].t<r.t-width do starts[w]=starts[w]+1 end
			r["nps"..width]=(i-starts[w]+1)/(width/1000)
		end
	end
	local streams={speed=0,hand=0,jack=0,chordjack=0,tech=0,stamina=0,course=0}
	local weights={speed=.22,hand=.18,jack=.16,chordjack=.16,tech=.12,stamina=.11,course=.05}
	local params={
		speed={200,2500,.75},hand={240,3000,.78},jack={280,2500,.85},chordjack={260,3000,.80},
		tech={450,3500,.70},stamina={1200,10000,.58},course={30000,120000,.35}}
	local sums={}; for name in pairs(streams) do sums[name]={burst=0,sustain=0,values={}} end
	local colLast,handLast,prevHand,handStamina={},{},{0,0},{0,0}
	local dtRowVals,dtHandVals,dtSameVals,localRaw={}, {}, {}, {}
	local chordRows,threeRows,overlapTotal,rotationTotal,eligible=0,0,0,0,0
	local anchorTotal,fastJackTotal,leftLoad,rightLoad=0,0,0,0
	local prevTime,prevDT,prevMask=rows[1].t-1000,1000,0
	local entropyStart=1
	for i,row in ipairs(rows) do
		local t,mask=row.t,row.mask; local dt=math.max(1,t-prevTime); dtRowVals[#dtRowVals+1]=dt
		local hands={row.left,row.right}; local dtHand={nil,nil}; local rotation={0,0}; local overlap=0
		for h=1,2 do if hands[h]~=0 then
			if handLast[h] then
				dtHand[h]=math.max(1,t-handLast[h]); dtHandVals[#dtHandVals+1]=dtHand[h]; eligible=eligible+1
				if prevHand[h]~=0 and not intersects(hands[h],prevHand[h]) then rotation[h]=1; rotationTotal=rotationTotal+1 end
				if intersects(hands[h],prevHand[h]) then overlap=overlap+1 end
			end
		end end
		local sameDT,jackMax,anchorRow={},0,0
		for c=1,4 do if bit(mask,c-1)==1 then
			if colLast[c] then
				sameDT[c]=math.max(1,t-colLast[c]); dtSameVals[#dtSameVals+1]=sameDT[c]
				anchorRow=math.max(anchorRow,invGate(sameDT[c],220,260)); fastJackTotal=fastJackTotal+invGate(sameDT[c],120,150)
				jackMax=math.max(jackMax,rate(sameDT[c],185,35,1.18,8))
			end
			colLast[c]=t
		end end
		anchorTotal=anchorTotal+anchorRow; leftLoad=leftLoad+row.lcount; rightLoad=rightLoad+row.rcount
		if row.size>=2 then chordRows=chordRows+1 end; if row.size>=3 then threeRows=threeRows+1 end
		while entropyStart<i and rows[entropyStart].t<t-750 do entropyStart=entropyStart+1 end
		local masks,transitions={},{}; local prev=entropyStart>1 and rows[entropyStart-1].mask or 0
		for j=entropyStart,i do local m=rows[j].mask; masks[m]=(masks[m] or 0)+1; if prev~=0 then local code=prev*16+m; transitions[code]=(transitions[code] or 0)+1 end; prev=m end
		local function entropy(counts,divisor)
			local total=0; for _,v in pairs(counts) do total=total+v end; if total==0 then return 0 end
			local h=0; for _,v in pairs(counts) do local p=v/total; h=h-p*math.log(p)/math.log(2) end
			return bioClamp(h/divisor,0,1)
		end
		local entMask,entTransition=entropy(masks,4),entropy(transitions,8)
		local dtSame=0; for _,v in pairs(sameDT) do dtSame=math.max(dtSame,v) end
		local sameHandOverlap=overlap/2; overlapTotal=overlapTotal+sameHandOverlap
		local handRates={}
		for h=1,2 do
			if hands[h]~=0 then
				local hd=dtHand[h] or 1000; local rr=rate(hd,180,38,1.10,8); handRates[#handRates+1]=rr
				handStamina[h]=decay(handStamina[h],rr,hd,8000)
			else handStamina[h]=decay(handStamina[h],0,dt,8000) end
		end
		local handMax,handMean=0,0; for _,v in ipairs(handRates) do handMax=math.max(handMax,v); handMean=handMean+v end
		if #handRates>0 then handMean=handMean/#handRates end
		local rowChord=(row.size-1)/3
		local sameHandChord=(math.max(0,row.lcount-1)+math.max(0,row.rcount-1))/2
		local speedIn=.55*rate(dt,180,40,1.08,8)+.30*handMax+.15*handMean
		local jackIn=jackMax*(1+.20*rowChord+.15*anchorRow)
		local handIn=0
		for h=1,2 do if hands[h]~=0 then local hd=dtHand[h] or 1000; handIn=math.max(handIn,.70*rate(hd,180,38,1.10,8)+.30*rotation[h]*rate(hd,205,45,1.05,8)) end end
		local body=math.max(0,row.size-2)*rate(dt,150,80,.85,8)
		local chordIn=rowChord*(1+.18*speedIn)+.22*sameHandChord+body
		local cjIn=rowChord*(.55*jackIn+.30*sameHandOverlap+.15*handIn)
		local chaos=prevMask~=0 and math.min(2,math.abs(math.log((dt+24)/(prevDT+24))/math.log(2)))/2 or 0
		local techIn=.32*chaos+.24*entMask+.24*entTransition+.20*(mask~=prevMask and 1 or 0)
		local staminaIn=.40*math.log(1+row.nps1000)/math.log(24)+.35*math.log(1+row.nps4000)/math.log(24)+.25*math.max(handStamina[1],handStamina[2])
		local courseIn=staminaIn*gate(activity.active_duration_s,90,300)*(1-.25*gate(activity.break_density,.006,.018))
		local inputs={speed=speedIn,hand=handIn,jack=jackIn,chordjack=cjIn,tech=techIn,stamina=staminaIn,course=courseIn}
		for name,v in pairs(inputs) do local p=params[name]; local state=sums[name]; state.burst=decay(state.burst,v,dt,p[1]); state.sustain=decay(state.sustain,v,dt,p[2]); state.values[#state.values+1]=p[3]*state.burst+(1-p[3])*state.sustain end
		local raw=0; for name,v in pairs(inputs) do raw=raw+weights[name]*sums[name].values[#sums[name].values] end; localRaw[#localRaw+1]=raw
		for h=1,2 do if hands[h]~=0 then handLast[h]=t; prevHand[h]=hands[h] end end
		prevTime,prevDT,prevMask=t,dt,mask
	end
	local summaries,streamsQ97,weightedAgg={}, {},0
	for name,s in pairs(sums) do
		local a=s.values; local q50,q75,q90,q97=quantile(a,.5),quantile(a,.75),quantile(a,.9),quantile(a,.97)
		local sorted=copyArray(a); table.sort(sorted); local tailN=math.max(1,math.ceil(#sorted*.04)); local tail=0; for i=#sorted-tailN+1,#sorted do tail=tail+sorted[i] end; tail=tail/tailN
		local power=0; for _,v in ipairs(sorted) do power=power+v^2.4 end; power=(power/#sorted)^(1/2.4)
		local agg=.30*q97+.22*q90+.18*tail+.15*q75+.10*power+.05*q50
		summaries[name]={aggregate=agg,q97=q97}; streamsQ97[name]=q97; weightedAgg=weightedAgg+weights[name]*agg
	end
	local q97,q75=quantile(localRaw,.97),quantile(localRaw,.75)
	local peakGap=bioClamp((q97-q75)/math.max(q97,1e-6),0,1)
	local first=rows[1].t; local sectionMax,smoothed={},localRaw[1]
	for i,row in ipairs(rows) do local sec=math.floor((row.t-first)/400); smoothed=smoothed+.15*(localRaw[i]-smoothed); sectionMax[sec]=math.max(sectionMax[sec] or 0,smoothed) end
	local sections={}; for _,v in pairs(sectionMax) do if v>0 then sections[#sections+1]=v end end; table.sort(sections,function(a,b)return a>b end)
	local secAgg,w,ws=0,1,0; for _,v in ipairs(sections) do secAgg=secAgg+v*w; ws=ws+w; w=w*.9 end; secAgg=secAgg/math.max(ws,1e-9)
	local rawAgg=.8*weightedAgg+.2*secAgg
	local maxCol,minCol=0,math.huge; for _,v in ipairs(colCount) do maxCol=math.max(maxCol,v); minCol=math.min(minCol,v) end
	local stats={active_duration_s=activity.active_duration_s,break_density=activity.break_density,avg_nps=activity.avg_nps,
		chord_rate=chordRows/#rows,three_rate=threeRows/#rows,overlap_rate=overlapTotal/#rows,rotation_rate=rotationTotal/math.max(eligible,1),
		same_hand_q10=quantile(copyArray(dtHandVals),.1),fast_jack_rate=fastJackTotal/math.max(#dtSameVals,1),
		anchor_rate=anchorTotal/#rows,anchor_imbalance=(maxCol-minCol)/#rows,
		hand_bias=math.abs(leftLoad-rightLoad)/math.max(leftLoad,rightLoad,1e-6),peak_to_sustain_gap=peakGap}
	local nps1,nps4={},{}; for _,r in ipairs(rows) do nps1[#nps1+1]=r.nps1000; nps4[#nps4+1]=r.nps4000 end
	local q50,q75,q90,q97=quantile(nps1,.5),quantile(nps1,.75),quantile(nps1,.9),quantile(nps1,.97)
	local logN=0; for _,v in ipairs(nps1) do logN=logN+math.log(1+v)/math.log(24) end
	local function sortedCopy(a) local r=copyArray(a); table.sort(r); return r end
	local dtRows=sortedCopy(dtRowVals); local dtHands=sortedCopy(dtHandVals); local dtSames=sortedCopy(dtSameVals)
	local sustain={nps1k_q50=q50,nps1k_q75=q75,nps1k_q90=q90,nps4k_q50=quantile(nps4,.5),nps4k_q75=quantile(nps4,.75),nps4k_q90=quantile(nps4,.9),
		nps1k_flatness=bioClamp(q50/math.max(q97,1e-6),0,1),log_nps1k_mean=logN/#nps1,
		dt_row_q25=quantile(dtRows,.25),dt_row_q50=quantile(dtRows,.5),dt_row_q75=quantile(dtRows,.75),
		dt_hand_q25=quantile(dtHands,.25),dt_hand_median=quantile(dtHands,.5),dt_same_q25=quantile(dtSames,.25),dt_same_median=quantile(dtSames,.5)}
	for k,v in pairs(sustain) do stats[k]=v end
	return {raw_agg=math.floor(rawAgg*10000+0.5)/10000,summaries=summaries,streams_q97=streamsQ97,stats=stats,streams={}}
end

