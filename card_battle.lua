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
	
	deck = {}
	for suit in all(suit_options) do
		for i=1,#nums do
			local disp = nums[i]
			
			local card = {
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
			
			add(deck,card)
		end
	end
	
	-- saving a list of all cards
	cards={}
	for card in all(deck) do
		add(cards,card)
	end
	
	
	-- todo: remove extra j/q/k from deck here
	
	
	phand={}
	ehand={}
	
	deal(phand,deck)
	deal(ehand,deck)
end

function deal(hand,deck,amt)
	if(not amt) amt=5
	
	for i=1,amt do
		card = deck[flr(rnd(#deck))+1]
		add(hand, card)
		del(deck, card)
	end
end

function mulligan(hand,deck)
	for card in all(hand) do
		add(deck, card)
		del(hand, card)
	end
	deal(hand,deck)
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