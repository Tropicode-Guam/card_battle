function init_hand(is_player, ncards)
	ncards = ncards or 5
	local pad = 8
	local hand = {
		is_player=is_player,
		y=is_player and 100 or 27-cardh,
		selected_i=nil,
		cards={},
		discarding={}
	}
	hand.select_dir = function(dir)
		if not hand.selected_i then
			hand.selected_i = flr(#hand.cards/2 + .5)
			hand.cards[hand.selected_i].selected=true
		else
			hand.cards[hand.selected_i].selected=false
			hand.selected_i = mid(1,hand.selected_i+dir,#hand.cards)
			hand.cards[hand.selected_i].selected=true
		end
	end
	hand.spot = function(i,hand_size)
		hand_size=hand_size or #hand.cards
		return {
			x=flr(64-(cardw*hand_size+pad*(hand_size-1))/2 + cardw*i + pad*i)+.5,
			y=hand.y
		}
	end
	hand.add_card = function(card, ct)
		local sz = #hand.cards + 1
		local i=0
		card.facedown = not hand.is_player
		for c in all(hand.cards) do
			move(c,hand.spot(i,sz),clock.schedule(ct.threshold*.2))
			i+=1
		end
		move(card,hand.spot(i,sz),ct)
		add(hand.cards,card)
	end
	hand.discard = function(card, ct, deck)
		deck=deck or discard_deck
		del(hand.cards,card)
		card.facedown = true
		add(hand.discarding, card)
		clock.schedule(ct.threshold,1,function()del(hand.discarding,card)end)
		add(deck.cards,card)
		move(card,deck,ct)
		local i=1
		for c in all(hand.cards) do
			move(c,hand.spot(i,#hand.cards+2),clock.schedule(ct.threshold*.2))
			i+=1
		end
	end
	hand.draw = function()
		for card in all(hand.cards) do
			card.draw()
		end
		for card in all(hand.discarding) do
			card.draw()
		end
	end
	return hand
end

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
 
	cardw = 11
	cardh = (13-2)
	deck = {
		cards={},
		x=110,y=64-cardh/2
	}
	discard_deck = {
		cards={},
		x=17,y=64-cardh/2
	}
	for suit in all(suit_options) do
		for i=1,#nums do
			local disp = nums[i]
			if chosen_jqk[disp] and chosen_jqk[disp] != suit then
				goto continue
			end

			local card = {}
			card = {
				x=deck.x,y=deck.y,w=cardw,
				selected=false,
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
                dead = false,
				draw=function()
					local s = card
					local y = s.y - (s.selected and 2 or 0)
					local borderc = 5+(s.selected and 1 or 0)
					line(s.x,s.y+12,s.x+cardw,s.y+12,13)
					if s.facedown then
						rectfill(s.x,s.y-2,s.x+cardw,s.y+13,5)
						rectfill(s.x+1,s.y-1,s.x+cardw-1,s.y+12,8)
						rect(s.x+2,s.y,s.x+cardw-2,s.y+11,borderc)
					else
						rectfill(s.x,y-2,s.x+s.w,y+13,7)
						print(s.disp,
							s.x+(s.disp == 10 and -3 or 1)+s.w-5,
							y,
							s.color
						)
						spr(s.spr,s.x+2,y+7)
						rect(s.x,y-2,s.x+s.w,y+13,borderc)
					end
				end
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
				if btnp(➡️) then
					phand.select_dir(1)
				elseif btnp(⬅️) then
					phand.select_dir(-1)
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

	-- animation controller
	anim_cont = {
		animations={},
		-- clock handles this
		-- update=function()
		-- 	local c=anim_cont
		-- end,
		draw=function()
			local c=anim_cont
			for a in all(c.animations) do
				a.draw(a)
				if a.ct.done then
					del(c.animations, a)
				end
			end
		end,
		animate=function(draw, ct)
			local c=anim_cont
			add(c.animations, {
				draw=draw,
				ct=ct
			})
		end
	}


	phand=init_hand(true)
	ehand=init_hand(false)
	
	deal(phand,deck)
	deal(ehand,deck)

	palt(0,false)
	palt(7,true)
end

function deal_card(card, hand, deck, deal_time)
	-- schedule animation here
	local ct = clock.schedule(deal_time,1, function()
		-- del(deck.cards, card)
	end)
	hand.add_card(card,ct)
end

function deal(hand,deck,amt)
	if(not amt) amt=5
	
	local deal_time = 5
	delay=0
	for i=1,amt do
		local card = deck.cards[flr(rnd(#deck.cards))+1]
		del(deck.cards, card)
		clock.schedule(delay,1,function()
			deal_card(card, hand, deck, deal_time)
		end)
		delay+=10
	end
	local ct = clock.schedule(delay+deal_time)
	controller.interrupt(ct)
end

function discard(card, hand, deck, deal_time)
	-- schedule animation here
	local ct = clock.schedule(deal_time,1, function()
		-- del(deck.cards, card)
	end)
	-- add(deck.cards, card)
	hand.discard(card,ct,deck)
end

function mulligan(hand,deck, speed)
	speed = speed or 2
	local delay = 0
	local deal_time = 5
	for card in all(hand.cards) do
		clock.schedule(delay,1,function()
			discard(card, hand, deck, deal_time)
		end)
		delay += speed
	end
	local ct = clock.schedule(delay+deal_time)
	controller.interrupt(ct)

	clock.schedule(delay+deal_time+1,1,function()
		deal(hand,deck)
	end)
end

function lerp(a,b,t)
	return b*t+a*(1-t)
end

function move(obj, target, ct, func)
	func = func or function(t)
		return t
	end
	local from = {x=obj.x,y=obj.y}
	local to = {x=target.x,y=target.y}
	local disp = obj.disp or ""
	anim_cont.animate(function(a)
		obj.x = lerp(from.x,to.x,ct.lt)
		obj.y = lerp(from.y,to.y,ct.lt)
	end, ct)
end

function _update()
	clock.update()
	controller.update()
end

function _draw()
	cls(7)

	-- draw deck
	-- todo: make this oop?
	rectfill(deck.x,deck.y-2,deck.x+cardw,deck.y+13,5)
	rectfill(deck.x+1,deck.y-1,deck.x+cardw-1,deck.y+12,8)
	rect(deck.x+2,deck.y,deck.x+cardw-2,deck.y+11,5)

	anim_cont.draw()
	phand.draw()
	ehand.draw()
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