function _init()
	suit_classes={
		diamonds={
			init=function(s)
				s.att += flr((s.hp+.5)/2)
			end,
		},
		hearts={
			init=function(s)
				s.hp = ceil(s.hp/2)
				s.eff = ceil(s.hp/2)
			end,
			play_after=function(s,spot)
				for i in all(spot.neighbors) do
					i.card.hp += s.eff
				end
			end,
		},
		spades={ -- ranger?
			init=function(s)
				s.eff = flr((s.hp+.5)/2)
			end,
			attack=function(s,spot)
				s.spot.card.hurt(s.spot.card,s.eff)
				for i in all(spot.neighbors) do
					i.card.hurt(i.card,s.eff)
				end
			end
		},
		clubs={ -- tank?
			init=function(s)
				s.hp += flr((s.hp+.5)/2)
			end
		}
	}
	nums={'a',2,3,4,5,6,7,8,9,10,'j','q','k'}
	
	suit_options={'clubs','spades','diamonds','hearts'}
	local colors={
		clubs=0,
		spades=0,
		diamonds=8,
		hearts=8
	}
	local sprs={
		hearts=1,
		diamonds=2,
		spades=3,
		clubs=4
	}

	local jqk={'j','q','k'}
	local chosen_jqk={}
	for disp in all(jqk) do
		local suit = suit_options[flr(rnd(#suit_options))+1]
		chosen_jqk[disp] = suit
	end
 
	deck = {
		cards={},
		pos={x=100,y=64}
	}
	for suit in all(suit_options) do
		for i=1,#nums do
			local disp = nums[i]
			if chosen_jqk[disp] and chosen_jqk[disp] != suit then
				goto continue
			end

			local card = {
				disp=disp,
				color=colors[suit],
				spr=sprs[suit],
                hp=i,
                cost=log2(i)+1,
                att=i,
                suit=suit,
                play_after=function(s,spot)end,
                attack=function(s,spot)
                    spot.card.hurt(spot.card,s.att)
                end,
                hurt=function(s,amt)
                    s.hp -= amt
                    if s.hp <= 0 then
                        s.dead = true
                    end
                end,
                dead = false
			}
			
			subclass=suit_classes[suit]
			for fname, func in pairs(subclass) do
				card[fname] = func
			end
			
			add(deck.cards,card)

			-- goto / continue label
			-- since lua has no continue keyword
			::continue::
		end
	end
	
	-- saving a list of all cards
	cards={}
	for card in all(deck.cards) do
		add(cards,card)
	end

	clock={
		ts={},
		schedule=function(threshold,speed,action)
			local ct = {
				t=threshold,
				threshold=threshold,
				lt=0, -- lifetime (0-1)
				speed=speed or 1,
				done=false,
				paused=false,
				action=action
			}
			add(clock.ts, ct)
			return ct
		end,
		update=function()
			for c in all(clock.ts) do
				if not c.paused then
					c.t = max(c.t - c.speed, 0)
					c.lt = (c.threshold-c.t)/c.threshold
					if c.t == 0 then
						c.done = true
						if c.action then
							c.action()
						end
						del(clock.ts, c)
					end
				end
			end
		end
	}
	controller={
		update=function()
			local c = controller
			if c.interactable() then
				if btnp(❎) then
					mulligan(phand,deck)
				end
			end
		end,
		interactable=function()
			local c = controller
			for ct in all(c.interrupts) do
				if ct.done then
					del(c.interrupts, ct)
				else
					return false
				end
			end
			return true
		end,
		interrupts={},
		interrupt=function(ct)
			add(controller.interrupts, ct)
		end
	}

	phand={}
	ehand={}
	
	deal(phand,deck)
	deal(ehand,deck)

	palt(0,false)
	palt(7,true)
end

function deal_card(card, hand, deck)
	-- schedule animation here
	add(hand, card)
	del(deck.cards, card)
end

function deal(hand,deck,amt)
	if(not amt) amt=5
	
	delay=0
	for i=1,amt do
		local card = deck.cards[flr(rnd(#deck.cards))+1]
		clock.schedule(delay,1,function()
			deal_card(card, hand, deck)
		end)
		delay+=5
	end
	local ct = clock.schedule(delay+1)
	controller.interrupt(ct)
end

function discard(card, hand, deck)
	-- schedule animation here
	add(deck.cards, card)
	del(hand, card)
end

function mulligan(hand,deck)
	local delay = 0
	for card in all(hand) do
		clock.schedule(delay,1,function()
			discard(card, hand, deck)
		end)
		delay += 5
	end
	local ct = clock.schedule(delay+1)
	controller.interrupt(ct)

	clock.schedule(delay,1,function()
		deal(hand,deck)
	end)
end


function _update()
	clock.update()
	controller.update()
end

function _draw()
	cls(7)
	i = 0
	pad = 8
	cardw = 11
	for card in all(phand) do
		x = flr(64-(cardw*#phand+pad*(#phand-1))/2 + cardw*i + pad*i)+.5
		off = card.disp == 10 and -3 or 1
		print(card.disp,
			x+off+cardw-5,
			100,
			card.color
		)
		spr(card.spr,x+2,100+7)
		rect(x,100-2,x+cardw,100+13,5)
		i += 1
	end
end

--helpers
function log10(n)
	if (n <= 0) return nil
	local f, t = 0, 0
	while n < 0.5 do
		n *= 2.71828
		t -= 1
	end
	while n > 1.5 do
		n /= 2.71828
		t += 1
	end
	
	n -= 1
	for i = 9, 1, -1 do
		f = n*(1/i - f)
	end
	t += f
	-- to change base, change the
	-- divisor below to ln(base)
	return t / 2.30259
end

function log2(n)
	if (n <= 0) return nil
	local f, t = 0, 0
	while n < 0.5 do
		n *= 2.71828
		t -= 1
	end
	while n > 1.5 do
		n /= 2.71828
		t += 1
	end
	
	n -= 1
	for i = 9, 1, -1 do
		f = n*(1/i - f)
	end
	t += f
	-- to change base, change the
	-- divisor below to ln(base)
	return t / 0.693147
end