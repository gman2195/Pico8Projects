pico-8 cartridge // http://www.pico-8.com
version 36
__lua__
--engine calls(main game loop)
function _init()
	cls()

	--[[gamestate
		0-press to start
		1-game start
		2-game over
	]]
	gs = 0

	--global increment
	i = 0

	--global framecount
	f = 0
	e = 0

	wave = 0
	flight = 3

	ecount = 0

	message = "waiting"

	pause = 120

	--entities(objects with collision) table
	entities = {}

	--background stars init
	stars = {}

	animations = {}

	for a=1,50 do
		createstar()
	end

	--player object
	pl = createplayer()

	--enemy object
	--need to create an all purpose enemy spawning function

end

function _draw()
	--press 🅾️ to start
	if gs==0 then
		print("press 🅾️ to start",30,60)
	end

	--game on
	if gs==1 then
		cls()

		--animate background stars
		for s in all(stars) do
			s.update(s)
		end

		map(0,0,0,0,16,16)

		--draw the entities on screen
		for s in all(entities) do
			s.draw(s)
		end

		--update animations
		for s in all(animations) do
			if s.owner then
				spr(s.sprite,s.owner.x,s.owner.y,s.size,s.size)
				if s.frames==0 then
					del(animations,s)
				elseif s.frames>0 then
					s.sprite+=s.size
					s.frames-=1
				elseif s.frames<0 then
					s.sprite-=s.size
					s.frames+=1
				end
			else
				spr(s.sprite,s.x,s.y,s.size,s.size)
				if s.frames==0 then
					del(animations,s)
				elseif s.frames>0 then
					s.sprite+=s.size
					s.frames-=1
				elseif s.frames<0 then
					s.sprite-=s.size
					s.frames+=1
				end
			end
		end

		--reset pen color after drawing flash
		color(7)

		--update health display
		for c=1,5 do
			spr((pl.hearts[c]+1)*16,-9+(9*c),1)
		end

		for c=1,pl.ammo do
			spr(48,-9+(9*c),9)
		end

		--display score
		print("wave: "..wave+1,80,1)
		print("flight: "..flight)
		print("score: "..pl.score)
		print("ecount: "..ecount)
		print("pause: "..pause)
		printh("message: "..message,"@clip")
		if pause>0 then
			print("wave "..(wave+1).." approaching!!!",20,60,flr(f/3)%4+7)
		end
	end
end

function _update()
	--press 🅾️ to start
	if gs==0 then
		--store input table
		pl.input = inputbin(btn())
		if pl.input[5]!=0 then gs=1 end
	end

	--game on
	if gs==1 then
		--count frame #
		f+=1
		if f<0 then f=0 end

		if e==0 then
			createwidepower(rnd(104)+8,-8)
			createbombenemy(70,-20)
			e=1
		end

		if pause>0 and ecount==0 then pause-=1 end

		if flight<=0 and pause==0 and ecount==0 then
			wave+=1
			flight=3+flr(wave*1.5)
			pause=120
		end

		--[[every 4 seconds spawn a wave of enemies
			waves consist of 1-3 randomly placed eye enemies, but as more enemy types
			are added they should be mixed into the spawning algorithm
		]]
		if f%120==0 and flight>0 and pause==0 then
			spawnenemywave(flr(rnd(3))+1, wave)
			flight-=1
		end

		--every 2 minutes spawn a power up
		if f%1200==0 then
			spawnpower()
		end

		if f%1800==0 then
			createammo(rnd(104)+8,-8)
		end

		--update player & enemy entities
		for s in all(entities) do
			s.update(s)
		end

		--checks for colisions between entities
		for _,s in pairs(entities) do
			for _,b in pairs(entities) do
				local col,a,b,x0,y0,y1=collide_aabox(s,b)
				if col and intersect_bitmasks(a,b,x0,y0,y1) and a!=b and not a.markdel and not b.markdel then
					a.collide(a,b)
					b.collide(b,a)
				end
			end
		end

		--check for a game over and set the game state
		if pl.hearts[1]==0 then
			print("game over",43,60,8)
			gs = 2
		end
	end

	--game over
	if gs==2 then

	end
end

-->8
--tools

--[[custom draw function that allows for flipping the sprite along the y axis
	without having to provide scaling or x flip values every call]]
function sprdraw(n,x,y,flip_y)
	spr(n,x,y,1,1,true,flip_y)
end
--[[
	a version of the inttobin
	function that is modified to
	accept the button input binary
	from btn() and store just the
	player 0 input in a returned table
]]
function inputbin(b)
 t={}
 a=0
 for i = 0,5 do
  a=2^i
  t[i+1]=band(a,b)/a
 end
 return t
end


-->8
--general gameplay logic
--a function to move the sprites around the screen
function smove(dx, dy, this)
	--check for diagonal movement and normalize
	if dx^2+dy^2>1 then
		dist = sqrt(dx^2+dy^2)
		this.dx=dx/dist
		this.dy=dy/dist
	else
		this.dx=dx
		this.dy=dy
	end

	--change players sprite coords
	this.x += this.dx*this.spd
	this.y += this.dy*this.spd

	--[[check for out of bounds and restrict movement
		the player is restricted to the screen bounds while the other entities
		are cleaned up as they move off screen]]
	if this.type == "pickup" then
		if this.x>=120 then
			this.x=120
			this.dx*=-1
		end
		if this.x<0 then
			this.x=0
			this.dx*=-1
		end
		if this.y>=120 then
			this.y=120
			this.dy*=-1
		end
		if this.y<0 then
			this.y=0
			this.dy*=-1
		end
	elseif this==pl then
		if this.x>120 then this.x=120 end
		if this.x<0 then this.x=0 end
		if this.y>112 then this.y=112 end
		if this.y<0 then this.y=0 end
	else
		if this.x>120 then this.x=120 end
		if this.x<0 then this.x=0 end
		if this.y>128 then this.destroy(this) end
	end
end

function spawnpower()
	local power = rnd(10)+wave*2
	if power>15 then
		createsplitpower(rnd(104)+8,-8)
	elseif power>10 then
		createwidepower(rnd(104)+8,-8)
	else
		createammo(rnd(104)+8,-8)
	end
end

--[[enemy wave spawning function, takes a number of enemies to spawn in the wave
	as an argument]]
function spawnenemywave(num, wave)
	--local enemy table to ensure enemies aren't spawned on top of eachother
	local enemy = {}
	local create = function(ex,ey)
		return createeyeenemy(ex,ey)
	end
	--init the 0 index to prevent nil index error
	enemy[0] = {x=0,y=0}
	--loop for creating each enemy
	for l=1,num do
		local type = rnd(10)+wave*2
		if type>15 then
			create = function(ex,ey)
				return createeliteenemy(ex,ey)
			end
		elseif type>10 then
			create = function(ex,ey)
				return createbombenemy(ex,ey)
			end
		else
			create = function(ex,ey)
				return createeyeenemy(ex,ey)
			end
		end
		--each enemy is created in a random position off screen
		local x,y = rnd(104/num)*l+8,
			rnd(60)-70
		--if enemies are too close to eachother, the current enemy is shifted to make room
		if x-8<enemy[l-1].x+8 then
			x+=12
		end
		if x>120 then x=120 end
		--create the enemy and store it locally for the next enemy to compare to
		add(enemy,
			create(x,y))
	end
end

--collision detection
function collide(sh1,sv1,sx1,sy1,ph1,pv1,sh2,sv2,sx2,sy2,ph2,pv2)
	local ok,x,y=0
 if (sx1*sy1>sx2*sy2) sh1,sv1,sx1,sy1,ph1,pv1,sh2,sv2,sx2,sy2,ph2,pv2=sh2,sv2,sx2,sy2,ph2,pv2,sh1,sv1,sx1,sy1,ph1,pv1
 for i=0,sy1-1 do
 	for j=0,sx1-1 do
  	x=j+ph1-ph2 y=i+pv1-pv2
   if (x>=0 and x<sx2 and y>=0 and y<sy2 and sget(sh1+j,sv1+i)>0 and sget(sh2+x,sv2+y)>0) return true
  end
 end
 return false
end


-- freds72 per-pixel api
function make_bitmask(sx,sy,sw,sh,tc)
 assert(flr(sw/32)<=1,"32+pixels wide sprites not yet supported")
 tc=tc or 0
 local bitmask={}
 for j=0,sh-1 do
  local bits,mask=0,0x1000.0000
  for i=0,sw-1 do
   local c=sget(sx+i,sy+j)
   if(c!=tc) bits=bor(bits,lshr(mask,i))
  end
  bitmask[j]=bits
 end
 return bitmask
end

function intersect_bitmasks(a,b,x,ymin,ymax)
 local by=flr(a.y)-flr(b.y)
 for y=ymin,ymax do
  -- out of boud b mask returns nil
  -- nil is evaluated as zero :]
  if(band(a.sprs[a.sprindex].mask[y],lshr(b.sprs[b.sprindex].mask[by+y],x))!=0) then return true end
 end
end

function collide_aabox(a,b)
 -- a is left most
 if(a.x>b.x) a,b=b,a
 -- screen coords
 local ax,ay,bx,by=flr(a.x),flr(a.y),flr(b.x),flr(b.y)
 local xmax,ymax=bx+8,by+8
 if ax<xmax and
  ax+8>bx and
  ay<ymax and
  ay+8>by then
  -- collision coords in a space
  return true,a,b,bx-ax,max(by-ay),min(by+8,ay+8)-ay
 end
end
-->8
--colliding objects

--[[ship objects
	in this case ships are anything that moves through space and has collision,
	so the player, enemies, power ups, and bullets are all derived from this object]]
function createship()
	local obj = {}
	--movement control fields
	obj.spd = 3
	obj.dx = 0
	obj.dy = 0
	obj.x = 60
	obj.y = 20
	--sprite and animation fields
	obj.sprs = {}
	obj.sprcount = 1
	obj.activespr = 2
	obj.flip = false
	obj.sprindex = 1
	--extra data fields
	obj.markdel = false
	obj.i = 0
	obj.owner = obj
	obj.dam = true
	obj.type = "none"

	--[[an initial creation function all colliding entities must call to populate their
		animation frames and collision bitmasks]]
	obj.commoncreate = function(this)
		this.sprs = {}
		if this.sprcount==1 then
			add(this.sprs,{
				num = this.activespr,
				mask = make_bitmask(this.activespr*8%128,this.activespr\16*8,8,8)
			})
		else
			for i=this.activespr,this.activespr+this.sprcount do
				add(this.sprs,{
					num = i,
					mask = make_bitmask(i*8%128,i\16*8,8,8)
				})
			end
		end
	end

	obj.commoncollide = function(this, collider)
		if this==collider or collider.owner==this or this.owner==collider or (this.owner.type==collider.type) or (this.type==collider.type) or (this.type=="pickup" and collider.type=="bullet") or (this.type=="bullet" and collider.type=="pickup") then
			return 0
		else
			this.damage(this)
		end
	end

	obj.damage = function(this)
		this.markfordeletion(this)
	end

	obj.collide = function(this,collider)
		this.commoncollide(this,collider)
	end

	obj.markfordeletion = function(this)
		this.markdel = true
	end

	obj.destroy = function(this)
		del(entities,this)
	end

	obj.commonupdate = function(this)
		if this.markdel then this.destroy(this) end
	end

	obj.update = function(this)
		this.commonupdate(this)
	end

	obj.commondraw = function(this)
		local y = 0
		if this!=pl then
			y = 8
		end
		if this.i-18!=0 then
			circfill(this.x+3,this.y-1+y,this.i-18,this.i-9)
			circfill(this.x+4,this.y-1+y,this.i-18,this.i-9)
		end
		sprdraw(this.sprs[this.sprindex].num,this.x,this.y,this.flip)
	end

	obj.draw = function(this)
		this.commondraw(this)
	end

	obj.firebullet = function(this)
		createbullet(this.x, this.y, this)
		this.i = 20
	end

	return obj
end

--generic enemy object
function createenemy(x,y)
	local obj = createship()
	obj.flip = true
	obj.x = x
	obj.y = y
	obj.dx = 0
	obj.dy = 1
	obj.dir = 0
	obj.type = "enemy"
	obj.points = 100
	obj.hp = 1

	obj.specificupdate = function(this)
		this.commonupdate(this)
		smove(this.dx, this.dy, this)
	end

	obj.destroy = function(this)
		del(entities,this)
	end

	obj.damage = function(this)
		if this.type=="enemy" and this.hp>0 then
			this.hp-=1
		end
		if (this.type=="enemy" and this.hp==0) or this.type=="pickup" then
			this.markfordeletion(this)
		end
	end

	obj.collide = function(this,collider)
		if collider.owner!=this and collider.type!="pickup" and collider.owner.type!=this.type then
			this.commoncollide(this,collider)
			if collider.owner==pl then
				pl.score+=obj.points
			end
			if this.markdel then
				for i=1,6 do
					sfx(3)
					add(animations,{sprite=64,frames=6,size=2,x=this.x-6,y=this.y})
				end
			else
				for i=1,7 do
					sfx(4)
					add(animations,{sprite=53,frames=7,size=1,owner=this,x=this.x,y=this.y})
					add(animations,{sprite=59,frames=-7,size=1,owner=this,x=this.x,y=this.y})
				end
			end
		end
	end
	return obj
end

function createeliteenemy(x,y)
	local obj = createenemy(x,y)
	obj.activespr = 26
	obj.spd = 1
	obj.sprcount = 1
	obj.points = 500
	obj.hp = 5
	ecount+=1

	obj.commoncreate(obj)

	obj.destroy = function(this)
		ecount-=1
		del(entities,this)
	end

	obj.firebullet = function(this)
		createsplitbullet(this.x,this.y,this)
		this.i=15
	end

	obj.update = function(this)
		this.dy=0.5
		if pl.x-8>this.x then this.dx=1
		elseif pl.x+8<this.x then this.dx=-1
		else this.dx=0 end

		if this.y>0 and this.i==0 then this.firebullet(this)
		elseif this.i<0 then this.i=0
		else this.i-=1 end

		this.specificupdate(this)
	end
	add(entities, obj)
	return obj
end

function createbombenemy(x,y)
	local obj = createenemy(x,y)
	obj.activespr = 37
	obj.sprcount = 2
	obj.timer = 0
	obj.spd = 0.5
	obj.points = 150
	obj.hp = 3
	ecount+=1

	obj.commoncreate(obj)

	obj.destroy = function(this)
		ecount-=1
		del(entities,this)
	end

	obj.update = function(this)
		if this.timer==0 and this.activespr==37 and this.y<15 then
			this.dy=1
		elseif this.timer==0 and this.activespr==37 then
			this.dy=0
			this.spd=0
			this.timer=60
		end

		if this.timer>0 then this.timer-=1 end
		if this.timer==0 and this.spd==0 then
			this.activespr=38
			this.sprindex=2
			this.spd=1
			this.dy=pl.y-this.y
			this.dx=pl.x-this.x
			createbomb(this.x,this.y,this)
		end

		this.specificupdate(this)
	end
	add(entities, obj)
	return obj
end

--specific enemy, the eye
function createeyeenemy(x,y)
	local obj = createenemy(x,y)
	obj.activespr = 21
	obj.an = 5
	obj.sprcount = 4
	obj.dir = rnd({0,0.125,0.25,0.375,0.5,0.625,0.75,0.875,1})
	obj.spd = 1
	ecount+=1

	obj.commoncreate(obj)

	obj.destroy = function(this)
		ecount-=1
		del(entities,this)
	end

	obj.update = function(this)
		if (pl.x<=this.x+8 and pl.x>=this.x-8 and this.y>0) and this.i==0 then this.firebullet(this)
		elseif this.i<0 then this.i=0
		else this.i-=1 end
		if this.an==0 then
			this.sprindex = this.activespr-20
			if this.sprs[this.sprindex].num>24 then this.activespr=21
			else this.activespr+=1 end
			this.an = 5
		else this.an-=1 end
		if f%30==0 then
			this.dx = sin(this.dir)
			this.dir+=0.125
			if this.dir>=1 then this.dir=-1 end
		end
		this.specificupdate(this)
	end
	add(entities, obj)
	return obj
end

--a specific ship object for the player
function createplayer()
	local obj = createship()
	obj.hearts = {1,1,1,1,1}
	obj.input = {}
	obj.flame = 5
	obj.score = 0
	obj.sprcount = 3
	obj.activespr = 1
	obj.y = 100
	obj.shield = 0
	obj.shieldspr = 9
	obj.power = 0
	obj.roll = 0
	obj.type = "player"
	obj.ammo = 3
	obj.timer = 0

	obj.commoncreate(obj)

	obj.damage = function(this)
		for i=5,1,-1 do
			if this.hearts[i]==1 then
				this.hearts[i]=0
				break
			end
		end
		this.shield=120
	end

	obj.collide = function(this,collider)
		if collider.dam and this.shield==0 then
			this.commoncollide(this,collider)
		end
	end

	obj.powerup = function(this,powerupname)
		if powerupname=="widegun" then
			this.power = 360
			this.firebullet = function(this)
				createwidebullet(this.x, this.y, this)
				this.i = 20
			end
		elseif powerupname=="ammo" then
			this.ammo+=1
		elseif powerupname=="splitgun" then
			this.power=360
			this.firebullet = function(this)
				createsplitbullet(this.x,this.y,this)
				this.i = 7
			end
		end
	end

	obj.bomb = function(this)
		createbomb(this.x,this.y,this)
		this.timer=30
		this.ammo-=1
	end

	obj.update = function(this)
		if this.markdel and this.shield==0 then this.damage(this) end
		if this.hearts[1]==1 and this.markdel then this.markdel = false end
		this.commonupdate(this)

		if this.shield!=0 then
			if this.shield<45 then
				this.shieldspr=this.shield%4+9
			elseif f%5==0 then
				this.shieldspr=this.shield%2+9
			end
			this.shield-=1
		end

		if this.power>0 then this.power-=1
		else this.firebullet = function(this)
			createbullet(this.x, this.y, this)
			this.i = 10
			end
		end

		if this.power<0 then this.power=0 end

		--store input table
		this.input = inputbin(btn())

		smove(this.input[2] - this.input[1],
			this.input[4] - this.input[3],
			this)

		--update animation frame
		if this.dx>0 then this.sprindex = 2 - ceil(this.dx)
		else this.sprindex = 2 - flr(this.dx) end
		if this.flame>7 then this.flame=5
		else this.flame+=1 end

		if this.i > 0 then this.i -= 1 end

		--detect shoot input
		if this.input[5] == 1 and this.i == 0 then
			this.firebullet(this)
		end

		if this.input[6] == 1 and this.ammo>0 and this.timer==0 then
			this.bomb(this)
		end
		if this.timer>0 then this.timer-=1 end
	end

	obj.draw = function(this)
		--draw player ship
		this.commondraw(this)
		if this.shield!=0 then
			sprdraw(this.shieldspr,this.x,this.y+1)
		end
		sprdraw(this.flame,this.x,this.y+8)
	end

	add(entities, obj)
	return obj
end

--a power up object the player can collect
function createpower(x,y)
	--[[the object extends the enemy object
		so that it flies the same direction and
		collides with the player]]
	local obj = createenemy(x,y)
	obj.spd = 2
	obj.sprcount = 2
	obj.an = 15
	obj.dx = rnd()
	obj.dy = rnd()
	obj.dam = false
	obj.type = "pickup"
	obj.flip = false

	add(entities, obj)
	return obj
end

function createammo(x,y)
	local obj = createpower(x,y)
	obj.activespr = 30

	obj.commoncreate(obj)

	obj.update = function(this)
		if this.an==0 then
			this.sprindex = this.activespr-29
			if this.sprs[this.sprindex].num>30 then this.activespr=30
			else this.activespr+=1 end
			this.an = 15
		else this.an-=1 end
		this.specificupdate(this)
	end

	obj.collide = function(this,collider)
		if collider==pl then
			this.commoncollide(this,collider)
			pl.powerup(pl,"ammo")
		end
	end
end

function createsplitpower(x,y)
	local obj = createpower(x,y)
	obj.activespr = 46

	obj.commoncreate(obj)

	obj.update = function(this)
		if this.an==0 then
			this.sprindex = this.activespr-45
			if this.sprs[this.sprindex].num>46 then this.activespr=46
			else this.activespr+=1 end
			this.an = 15
		else this.an-=1 end
		this.specificupdate(this)
	end

	obj.collide = function(this,collider)
		if collider==pl then
			this.commoncollide(this,collider)
			pl.powerup(pl,"splitgun")
		end
	end
end

function createwidepower(x,y)
	local obj = createpower(x,y)
	obj.activespr = 14

	obj.commoncreate(obj)

	obj.update = function(this)
		if this.an==0 then
			this.sprindex = this.activespr-13
			if this.sprs[this.sprindex].num>14 then this.activespr=14
			else this.activespr+=1 end
			this.an = 15
		else this.an-=1 end
		this.specificupdate(this)
	end

	obj.collide = function(this,collider)
		if collider==pl then
			this.commoncollide(this,collider)
			pl.powerup(pl,"widegun")
		end
	end
end

--bullet object
function createbullet(x,y,owner)
	local bull = createship()
	bull.x = x
	bull.y = y
	bull.spd = 5
	bull.owner = owner
	bull.activespr = 19
	bull.type = "bullet"

	bull.commoncreate(bull)

	--enemy bullets shoot down
	if bull.owner!=pl then bull.spd*=-1 end



	bull.commondraw = function(this)
		if(this.owner!=pl) then
			sprdraw(this.activespr, this.x, this.y,true)
		else
			sprdraw(this.activespr, this.x, this.y)
		end

		this.y -= this.spd

		if (this.y<0 or this.y>120) then this.destroy(this) end
	end

	bull.draw = function(this)
		this.commondraw(this)
	end

	bull.update = function(this)
		this.commonupdate(this)
	end
	add(entities, bull)
	sfx(2)
	return bull
end

function createbomb(x, y, owner)
	local obj = createbullet(x,y,owner)
	obj.sprcount = 5
	obj.activespr = 39
	obj.spd = 0.5
	obj.timer = 30
	obj.fuse = -1
	obj.dam = true


	obj.commoncreate(obj)

	obj.destroy = function(this)
		for i=1,6 do
			sfx(3)
			add(animations,{sprite=64,frames=6,size=2,x=this.x-6,y=this.y})
		end
		this.explode(this)
		del(entities,this)
	end

	obj.explode = function(this)
		for s in all(entities) do
			if sqrt((this.x-s.x)^2+(this.y-s.y)^2)<24 then
					s.collide(s,this)
			end
			this.markfordeletion(this)
		end
	end

	obj.draw = function(this)
		if this.owner==pl then pal(8,12,0)
		else pal(12,8,0) end
		this.commondraw(this)
		pal()
	end

	obj.update = function(this)
		this.commonupdate(this)
		if this.activespr<41 and this.timer==0 then
			this.activespr+=1
			this.timer=30
		elseif this.activespr==42 and this.timer==0 then
			this.activespr=43
			this.timer=5
		elseif this.activespr==43 and this.timer==0 then
			this.activespr=42
			this.timer=5
		end
		if this.activespr==41 and this.timer==0 then
			this.activespr+=1
			this.timer=5
			this.fuse=45
		end
		if this.fuse>0 then this.fuse-=1 end
		if this.fuse==0 then
			this.explode(this)
		end
		this.sprindex=this.activespr-38
		if this.timer>0 then this.timer-=1 end
	end
end

function createsplitbullet(x,y,owner)
	local obj = createbullet(x,y,owner)
	obj.sprcount = 1
	obj.activespr = 18


	obj.commoncreate(obj)
end

--special bullet type
function createwidebullet(x, y, owner)
	local bull = createbullet(x,y,owner)
	bull.sprcount = 4
	bull.activespr = 33
	bull.spd = 2


	bull.commoncreate(bull)

	bull.update = function(this)
		this.sprindex = this.activespr - 32
		this.commonupdate(this)
		if i > 0 then
			i -= 1
		else
			i = 3
			if this.activespr < 36 then
				this.activespr += 1
			end
		end
		this.y -= this.spd
	end
end
-->8
--background/non-colliding objects

--star object
function createstar()
	local star = {}
	local col1 = {1,2,4,5,6,13,15}
	local col2 = {7,8,9,10,12,14}

	star.create = function(this)
		this.x = rnd(20000)%119+1
		this.y = rnd(2000)%30-30
		this.spd = rnd(3000)%8
		if (this.spd < 3) then this.cl = rnd(col1)
		else this.cl = rnd(col2) end
	end

	star.create(star)

	star.destroy = function(this)
		del(stars,this)
	end

	star.update = function(this)
		local y = this.y
		while (this.y<y+this.spd) do
			pset(this.x,this.y,0)
			this.y += 1
			pset(this.x,this.y,this.cl)
		end
		if (this.y>120) then
			this.create(this)
		end
	end

	add(stars, star)
	return star
end
__gfx__
000000000005500000055000000550000005500000077000000770000007700000077000000cc000000cc000000ee000000ee0000000000000cccc0000dddd00
0000000000567500005765000057650000566500000770000077770000777700007777000ccc76c00c677cc00eee76e00e677ee0000000000c6666c00d6666d0
0070070000566500005765000056650000566500000cc00000c77c000077770000c77c000c000760067000c00e000760067000e000000000c66bb66cd66bb66d
000770000566650005766650005666500566665000000000000cc00000c77c00000cc000c700007cc70000cce700007ee70000ee00000000c6bbbb6cd6bbbb6d
0007700005c767505767c66505767c50565665650000000000000000000cc00000000000c700007ccc00007ce700007eee00007e00000000cbb33bbcdbb33bbd
0070070005cc6650566cc6650566cc505656656500000000000000000000000000000000067000c00c000760067000e00e00076000000000cb3663bcdb3663bd
0000000005dd6500056dd6500056dd5005766750000000000000000000000000000000000c67ccc00cc776c00e67eee00ee776e0000000000c6666c00d6666d0
000000000088550000855800005588000085580000000000000000000000000000000000000cc000000cc000000ee000000ee0000000000000cccc0000dddd00
088008800000000000000000000c0000000000000c0000c00c0000c00c0000c00c0000c00c0000c00008800000000000000000000000000000cccc0000dddd00
80088008000330000000000000c7c0000000000001cccc1001cccc1001cccc1001cccc1001cccc10000880000000000000000000000000000c6648c00d6648d0
80000008003773000800008000c7c00000000000c167761cc1dddd1cc1dddd1cc1dddd1cc167761c00855800000000000000000000000000c654556cd654556d
80000008037bb7309800008900c7c00000000000c678676ccdd86ddccdd11ddccdd86ddcc678676c09555590000000000000000000000000c555555cd555555d
0800008037b33b739a0000a90007000000000000c678876cc678876cc111111cc678876cc678876c0857c580000000000000000000000000c555555cd555555d
008008007b0000b7700000070000000000000000c667766ccdd77ddccdd11ddccdd77ddcc667766c885cc588000000000000000000000000c655556cd655556d
00088000b000000b000000000000000000000000cc6666ccccddddccccddddccccddddcccc6666cc885995880000000000000000000000000c6666c00d6666d0
00000000000000000000000000000000000000000cccccc00cccccc00cccccc00cccccc00cccccc08000000800000000000000000000000000cccc0000dddd00
088008800000000000000000000000000000000002055020020000200000000000000000000000000000000000000000000000000000000000cccc0000dddd00
88888888000330000003300000033000000330000258552002000020005555000055550000555500005555000055550000000000000000000c6666c00d6666d0
88888888000bb000003bb300003bb30000377300dd5585dddd0000dd05588550055885500558855005855850058558500000000000000000c686686cd686686d
888888880000000000b00b0003b77b30037bb730d105501dd100001d05555850055558500555855005558550055855500000000000000000c986689cd986689d
0888888000000000000000000b0000b037b33b73d111111dd111111d05588550055585500555855005585550055585500000000000000000c9a66a9cd9a66a9d
008888000000000000000000000000007b0000b7d117c11dd117c11d05555850055888500555855005855850058558500000000000000000c766667cd766667d
00088000000000000000000000000000b000000bd1dccd1dd1dccd1d005555000055550000555500005555000055550000000000000000000c6666c00d6666d0
00000000000000000000000000000000000000000dddddd00dddddd00000000000000000000000000000000000000000000000000000000000cccc0000dddd00
00000480000000000000000000000000000000000000000000000000000000000000000000000000000cc000000cc00000000000000000000000000000000000
00554500005555000000000000000000000000000000000000000000000000000cc00cc00cc00cc00cc00cc00000000000000000000000000000000000000000
05545550050000500000000000000000000000000000000000000000000000000c0000c00c0000c00c0000c00000000000000000000000000000000000000000
55545555500000050000000000000000000000000000000000000000c000000cc000000cc000000c000000000000000000000000000000000000000000000000
55555555500000050000000000000000000000000000000000000000c000000cc000000cc000000c000000000000000000000000000000000000000000000000
5555555550000005000000000000000000000000000000000c0000c00c0000c00000000000000000000000000000000000000000000000000000000000000000
0555555005000050000000000000000000000000000000000cc00cc00cc00cc00000000000000000000000000000000000000000000000000000000000000000
0055550000555500000000000000000000000000000cc000000cc000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000052555550000000005255555000000000025055500000000002505550000000000000000000000000000000000
00000000000000000000000000000000000005525282500000000552528250000000055052005000000000505200500000000000000000000000000000000000
00000000000000000000000000770000000055288898850000005555229825000000550020002500000055002000050000000000000000000000000000000000
0000007007a00000000000a099a000000005228899a9825500052225598925550005020000800555000502000000055500000000000000000000000000000000
00000000a77a07000000079a77aa0a000052889aaaaa98500052228aa55a55500050000aa55a0050005000000000005000000000000000000000000000000000
0000700977770000000079a7777a9000005289aa77aa992000525889585525000000508900052000000050000000000000000000000000000000000000000000
0000007777770000000aaa777777900005589aa777aaa92505528599599825050550809000002505050000000000000500000000000000000000000000000000
00000a7777790000000a97777779900005289aa7777aa92005228a559988555005200a5090805000000000000000000000000000000000000000000000000000
00070777777a0000000a9a777779000000589aaaaaaaa92000585558592959500008050000290050000000000000005000000000000000000000000000000000
000000a77a0000000000aaa77a99000005559aaaaaa9982005555859982555250500085090000025000000000000000500000000000000000000000000000000
0007700a900770000000a99aaa0aa000052899aaaa988255052898a5a8582255052800a500500255000000000000000500000000000000000000000000000000
00070000070000000007aaa99a000000005289999988850000528885558522000050000555002200005000000000000000000000000000000000000000000000
0000000007000000000000000a000000000588888222505000052225522550500005200000055050000020000000505000000000000000000000000000000000
00000000000000000000000000000000005525525555500000552552555050000055005000505000005500500050500000000000000000000000000000000000
00000000000000000000000000000000050050552500000005005055250000000500505525000000050050552500000000000000000000000000000000000000
00000000000000000000000000000000000000005000000000000000500000000000000050000000000000005000000000000000000000000000000000000000
00c0c1cccc1c0c0000c0c1cccc1c0c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001ccc1111ccc100001ccc1111ccc100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0c1cddddddddc1c00c1cddddddddc1c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0ccd67822876dcc00ccd67822876dcc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ccd6678888766dccccd6678888766dcc000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
cc666677776666cccc666677776666cc000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5cd6666666666dc55cd6666666666dc5000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
05cd66666666dc5005cd66666666dc50000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
055cddddddddc550055cddddddddc550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00d5cccccccc5d0000d5cccccccc5d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0d5d5cccccc5dd000d5d5cccccc5dd00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0d5d0100010d50000d5d0100010d5000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00d5d010001d5d0000d5d010001d5d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000d50100010d500000d50100010d500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00d5d100000105d000d5d100000105d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00d50100000105d000d50100000105d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e8888e8ee888888efe8e888800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8e8ee8e28eee88efffe8888e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
88e88eff8e88e8e22e8e8ee800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8e888ef2e88e88e222e8e88e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e8e8e22f8ee8e8e222e88e8800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e88ef22288888eff2fe888e800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8ee2f222ee8ee8efffe88e8e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e2f2222288e88e8e2e8ee88800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e8ee888e8888e8e2fe8eee8800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2e88e8e8888e8ef22ee888e800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
fe8e8e888ee88eff2fe8888e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
22e888e8e8888e22ffe888e800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2ffe88e88ee8e8e22e8eee8800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2222ee8e888ee8effe8888e800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2222ffe88ee88e8ee8e8ee8e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
222f2f2ee888888ee88e888800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e2f2f2228888888ee88eee8800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8eff2222e88e888ee8e888e800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e8ee22228ee8e8effe8e888e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8e88eff2e8888effffe8e8e800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8e888e22e8888e2222e88e8800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
88e8e8ef8e888e2222e888ee00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8e8e88e288ee8ef22fe88e8800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e888ee8e8888e8effe8ee88800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
22222f2ee888888e2222222288888888000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
222f2ee88e888ee82222222288888888000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
222fe88e8e88e8882222222288888888000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
f22e8e8e8e888e882222222288888888000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2fe888e888e888e82222222288888888000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ffe88e8888e88e882222222288888888000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2e8ee8e88e8ee8e82222222288888888000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e8e8888ee888888e2222222288888888000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
00010000000000b050110502d050360503e0500000000000000000f00007000000000000000000121000000000000000000300000000000000000000000000000000000000000000000000000000000000000000
000100000000029050250501f0501a0501305012050110500f0500c0500a0500905006050040500505003050010500305002050030500405006050090500b0500c0500f050160501a0501d050230502d05000000
000200002052017520105200c5200a5200f520185202652034520335001c5002c500395001a5001a5001b5001e500236002760031600396003c60000700007000070001700027000270001700007000970004700
00030000276502f650346503565034650306502a6501f650166500d650086500665006650096500f6501365005700077000570006700067000670007700077000060000600000000000000000000000000000000
000200001755015550115500d5500a55008550085500955009550095500a5500b5500d550145501a55020550255502a5502250023500000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4710000028750160001700014100287500c0000f0001210028750170001700016000277501c700170001800028750150000000000000287500000000000000002875000000000000000027750000000000000000
001000081c0501b1501a250183501645013550106500e750087000870009700097000b7000c7000e7001070012700137000000000000000000000000000000000000000000000000000000000000000000000000
__music__
00 0a0b4344
