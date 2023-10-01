--@name Win95 lib
--@author Elias

window=class("window")

if SERVER then
    local waitList={}
    local keyboard=prop.createSent(chip():getPos()-chip():getUp()*1,Angle(),"gmod_wire_keyboard",true,{
        AutoBuffer=true,
        EnterKeyAscii=true,
        Model="models/jaanus/wiretool/wiretool_pixel_sml.mdl",
        Synchronous=true
    })
    keyboard:setColor(Color(0,0,0,0))
    
    wire.adjustInputs({"Memory","Usage"},{"string","normal"})
    wire.adjustOutputs({"Reset"},{"normal"})
    wire.create(chip(),keyboard,"Memory","Output")
    wire.create(chip(),keyboard,"Usage","InUse")
    wire.create(keyboard,chip(),"Reset Output String","Reset")

    net.receive("sv_passback",function()
        net.start("cl_passback"..net.readString())
        net.writeTable(net.readTable())
        net.send()
    end)

    function queue(time,func,data)
        if !waitList[time] then
            waitList[time]={}
            local list=waitList[time]
                    
            func()
                    
            timer.create("waitList_"..time,time,0,function()
                if list[#waitList[time]] then
                    list[#waitList[time]]()
                    
                    waitList[time][#waitList[time]]=nil
                else
                    timer.remove("waitList_"..time)
                    
                    waitList[time]=nil
                end
            end)
        else
            table.insert(waitList[time],1,func)
        end
    end

    net.receive("cl_edit",function(len,ply)
        local last
        local packet=net.readTable()
        
        keyboard:use(0,0)
        
        hook.add("think","sv_keyboard",function()
            local data=wire.ports.Memory
            
            if last!=data then
                queue(1/10,function()
                    net.start("cl_sync"..packet[1])
                    net.writeTable({tostring(data),packet[2]})
                    net.send()
                end)
                
                last=data
            end
            
            if wire.ports.Usage==0 then
                hook.remove("think","sv_keyboard")
            end
        end)
    end)
    
    net.receive("sv_dragSync",function(len,ply)
        local packet=net.readTable()
        
        net.start("cl_dragSync"..packet[2])
        net.writeTable(packet)
        net.writeEntity(ply)
        net.send((packet[1]=="setSync" and (!game.isSinglePlayer()) and #find.allPlayers()!=1) and find.allPlayers(function(plyI)
            if plyI!=ply then
                return plyI
            end
        end) or nil)
    end)
else
    local fps_delta = 1/30
    local icons={
        cursor=render.createMaterial("https://cdn.discordapp.com/attachments/1120967741801762919/1148745004609716254/arrow.png"),
        checkmark=render.createMaterial("https://cdn.discordapp.com/attachments/1120967741801762919/1148317574124281886/checkmark.png"),
        minmax=render.createMaterial("https://cdn.discordapp.com/attachments/1120967741801762919/1148472663384268871/min_max.png"),
        close=render.createMaterial("https://cdn.discordapp.com/attachments/1120967741801762919/1148472663052914698/close.png")
    }
    local clr={
        blue=Color(0,0,128),
        sliver=Color(229,229,229),
        black9=Color(90,90,90),
        black5=Color(50,50,50),
        white=Color(235,235,235),
        gray=Color(192,192,192)
    }
    
    function window:play(url,volume)
        bass.loadURL(url,"noblock 3d",function(snd,_,err)
            if snd then
                snd:setVolume(volume)
                snd:play()
                
                hook.add("think","play_"..url..self.name,function()
                    try(function()
                        snd:setPos(self.renderer:getPos())
                    end)
                end)
                
                timer.simple(snd:getLength(),function()
                    hook.remove("think","play_"..url..self.name)
                    snd:stop()
                end)
            else
                print(err) --replace with error window
            end
        end)
    end
    
    function window:drawHitBox(id,x,y,w,h,callBack)
        if self.hitboxes[id] then
            return
        end

        self.hitboxes[id]={
            Vector(y,x),
            Vector(y+h,x+w),
            callBack,
            true,
            false
        }
    end
    
    function reset()
        render.setStencilWriteMask(0xFF)
        render.setStencilTestMask(0xFF)
        render.setStencilReferenceValue(0)
        render.setStencilCompareFunction(STENCIL.ALWAYS)
        render.setStencilPassOperation(STENCIL.KEEP)
        render.setStencilFailOperation(STENCIL.KEEP)
        render.setStencilZFailOperation(STENCIL.KEEP)
        render.clearStencil()
    end
        
    function mask(mask, target, invert)
        reset()
            
        render.setStencilEnable(true)
        render.setStencilReferenceValue(1)
        render.setStencilCompareFunction(1)
        render.setStencilFailOperation(3)
            
        mask()
            
        render.setStencilCompareFunction(invert and 6 or 3)
        render.setStencilFailOperation(1)
            
        target()
            
        render.setStencilEnable(false)
    end
    
    function window:initialize(name,style,pos,ang,parentWin,title)
        self.name=name
        self.style=style
        self.style.last={}
        self.style.x=self.style.x or 0
        self.style.y=self.style.y or 0
        self.parentWin=parentWin
        self.hitboxes={}
        self.data={
            next_frame=0,
            cursor={Vector(0)},
            errors=0,
            user={}
        }

        render.createRenderTarget(self.name)
        
        self.h1=render.createFont("DebugFixed",self.style.fonts and self.style.fonts.large or 21.5,300,false)
        self.h2=render.createFont("DebugFixedSmall",self.style.fonts and self.style.fonts.small or 11.5,300,false)
    
        self.mat = material.create("UnlitGeneric") 
        self.mat:setTextureRenderTarget("$basetexture",name)
        self.mat:setInt("$flags",0)   
        self.mat:setInt("$flags",256) 
        
        hook.add("renderoffscreen","render_"..self.name,function()
            render.setFilterMin(1)
            render.setFilterMag(1)
            
            try(function()
                self.mouse=self.renderer:worldToLocal(trace.intersectRayWithPlane(player():getEyePos(), player():getEyeTrace().Normal, self.renderer:getPos(), self.renderer:getUp()))*28.5+Vector(512)
                self.mouse[3]=0
                self.data.cursor[1]=self.mouse
            end)
            
            local now = timer.systime()
            
            if self.data.next_frame > now then 
                return 
            end
            
            self.data.next_frame = now + fps_delta
        
            render.selectRenderTarget(name)
            
            render.clear(Color(0,0,0,0))
            
            if self.renderer:getUp():dot(player():getAimVector())>0 then
                self.renderer:setScale(Vector(self.style.size,-self.style.size,self.style.size))
                
                render.setColor(clr.gray)
                render.drawRectFast(self.style.x+5+self.style.width*0.52,self.style.y+5,self.style.width*0.52,self.style.height*0.52)
                                
                return
            else
                self.renderer:setScale(Vector(self.style.size))
            end
            
            render.setColor(clr.gray)
            render.drawRectFast(self.style.x+5,self.style.y+5,self.style.width*0.52,self.style.height*0.52)
            
            render.setFont(self.h2)
            
            if self.paint then
                self.paint()
            end
            
            render.setColor(clr.blue)
            render.drawRectFast(self.style.x+5,self.style.y+5,self.style.width*0.52,25)
            
            self:drawHitBox(0,self.style.x+5,self.style.y+5,self.style.width*0.52-59,25,function()
                local distOffset=self.renderer:getPos():getDistance(player():getEyePos())-5
                
                net.start("sv_dragSync")
                net.writeTable({true,self.name,self.data.cursor[1],distOffset})
                net.send()
                
                hook.add("mouseWheeled","dist_"..self.name,function(delta)
                    distOffset=distOffset+(delta*2)
                        
                    net.start("sv_dragSync")
                    net.writeTable({"setSync",self.name,nil,distOffset,player():keyDown(81)})
                    net.send()
                end)
                
                hook.add("think","dragLock_"..self.name,function()
                    if !self.hitboxes[0][5] then
                        hook.remove("think","dragLock_"..self.name)
                        hook.remove("mouseWheeled","dist_"..self.name)
                                        
                        net.start("sv_dragSync")
                        net.writeTable({false,self.name,self.data.cursor[1]})
                        net.send()
                        
                        return
                    end
                end)
            end)
            
            render.setFont(self.h1)
            render.setColor(Color(255,255,255))
            render.drawText(self.style.x+(self.style.icon and 28 or 15),self.style.y+9,self.style.title or self.name)
            
            render.setMaterial(icons.minmax)
            render.drawTexturedRectUV(self.style.x+self.style.width*0.52-54,self.style.y+12.5,15*2.29,15,0,0,32/1024,14/1024)
            
            self:drawHitBox(-1,self.style.x+self.style.width*0.52-54,self.style.y+12.5,17,15,function()
            
            end)

            self:drawHitBox(-2,self.style.x+self.style.width*0.52-37,self.style.y+12.5,17.29,15,function()
                net.start("sv_passback")
                net.writeString(self.name)
                net.writeTable({true,false})
                net.send()
            end)
            
            render.setMaterial(icons.close)
            render.drawTexturedRectUV(self.style.x+self.style.width*0.52-17,self.style.y+12.5,15,15,0,0,16/1024,14/1024)
            
            self:drawHitBox(-3,self.style.x+self.style.width*0.52-17,self.style.y+12.5,15,15,function()
                net.start("sv_passback")
                net.writeString(self.name)
                net.writeTable({false,true})
                net.send()
            end)
            
            if self.style.icon then
                render.setMaterial(self.style.icon)
                render.drawTexturedRectUV(self.style.x+12,self.style.y+12.5,15,15,0,0,32/1024,32/1024)
            end
            
            render.setColor(clr.sliver)
            render.drawRectOutline(self.style.x+5,self.style.y+5,self.style.width*0.52,self.style.height*0.52,5)
            
            if self.overlay then
                self.overlay()
            end
            
            render.setMaterial(icons.cursor)
            render.setColor(Color(255,255,255))
            
            if self.data.cursor[1] and Vector(self.data.cursor[1][2]-3.2,self.data.cursor[1][1]):withinAABox(Vector(self.style.x+5,self.style.y+5),Vector(self.style.x+5+self.style.width*0.52,self.style.y+5+self.style.height*0.52)) then
                render.drawTexturedRectUV(self.data.cursor[1][2]-3.2,self.data.cursor[1][1],30,30,0,0,32/1024,32/1024)
            end
            
            if !debugging then 
                return 
            end
            
            for id, hitbox in pairs(self.hitboxes) do
                local topLeft=hitbox[1]
                local bottomRight=hitbox[2]
                
                render.setColor(Color((timer.realtime()*40)+id*20,1,1):hsvToRGB())
                render.drawLine(topLeft[2],topLeft[1],bottomRight[2],bottomRight[1])
                render.drawRectOutline(topLeft[2],topLeft[1],bottomRight[2]-topLeft[2],bottomRight[1]-topLeft[1],1)
            end
        end)

        self.renderer = holograms.create(pos or chip():getPos(), ang or Angle(90,-90,0), "models/holograms/plane.mdl",Vector(self.style.size))
        self.renderer:setMaterial("!" .. self.mat:getName())
        self.renderer:setFilterMin(1)
        self.renderer:setFilterMag(1)

        net.receive("cl_passback"..self.name,function()
            local packet=net.readTable()
            
            if packet[1] then
                self.hitboxes={}
                self.style.fullscreen=not self.style.fullscreen
                
                if !self.style.fullscreen then
                    self.style.x=self.style.last[1]
                    self.style.y=self.style.last[2]
                    self.style.width=self.style.last[3]
                    self.style.height=self.style.last[4]
                else
                    self.style.last[1]=self.style.x
                    self.style.last[2]=self.style.y
                    self.style.last[3]=self.style.width
                    self.style.last[4]=self.style.height
                    self.style.x=0
                    self.style.y=0
                    self.style.width=(980*2)-5
                    self.style.height=(980*2)-5
                end
            end
            
            if packet[2] then
                hook.remove("renderoffscreen","render_"..self.name)
                hook.remove("think","hitboxes_"..self.name)
                
                for i, hitbox in pairs(self.hitboxes) do
                    if hitbox[3] then
                        hook.remove("inputPressed","hitId_"..i..self.name)
                        hook.remove("inputReleased","hitId_"..i..self.name)
                    end
                end
                
                self.renderer:remove()
                
                self.hitboxes=nil
                self=nil
            end
        end)

        net.receive("cl_sync"..self.name,function()
            local packet=net.readTable()

            if self.hitboxes[packet[2]] then
                self.hitboxes[packet[2]][6]=packet[1]
            end
        end)
        
        net.receive("cl_dragSync"..self.name,function()
            local packet=net.readTable()
            local ent=net.readEntity()
            self.distOffset=packet[4]
            self.snap=packet[5]
            
            if player()==ent then
                hook.add("mouseWheeled","cldist_"..self.name,function(delta)
                    self.distOffset=self.distOffset+(delta*2)
                end)
                
                hook.add("inputPressed","clmisc_"..self.name,function(key)
                    if key==81 or key==82 then
                        self.snap=true
                        
                        net.start("sv_dragSync")
                        net.writeTable({"setSync",self.name,nil,self.distOffset,true})
                        net.send()
                    end
                end)
                
                hook.add("inputReleased","clmisc_"..self.name,function(key)
                    if key==81 or key==82 then
                        self.snap=false
                                                
                        net.start("sv_dragSync")
                        net.writeTable({"setSync",self.name,nil,self.distOffset,false})
                        net.send()
                    end
                end)
            end
            
            if packet[1]=="setSync" then
                return
            end
            
            if packet[1] then
                hook.add("think","dragging_"..self.name,function()
                    local Trace=ent:getEyeTrace().Normal
                    
                    self.renderer:setAngles(Angle(self.snap and 0 or math.round(ent:getEyeAngles()[1]/10)*10,ent:getEyeAngles()[2],0)+Angle(90,0,180))
                    self.renderer:setPos((ent:getEyePos()+Trace*self.distOffset)+(((ent:getRight()/4)*(512-packet[3][2]))/8)-(((ent:getUp()/3.6)*(512-packet[3][1]))/8))
                end)
            else
                hook.remove("think","dragging_"..self.name)
                
                if player()==ent then
                    hook.remove("mouseWheeled","cldist_"..self.name)
                    hook.remove("inputPressed","clmisc_"..self.name)
                    hook.remove("inputReleased","clmisc_"..self.name)
                end
            end
        end)
        
        hook.add("think","hitboxes_"..self.name,function()
            if !self.data.cursor[1] then
                return
            end
            
            for i, hitbox in pairs(self.hitboxes) do
                if self.data.cursor[1]:withinAABox(hitbox[1],hitbox[2]) then
                    if !hitbox[4] then
                        hitbox[4]=true
                        
                        if hitbox[3] then
                            hook.add("inputPressed","hitId_"..i..self.name,function(key)
                                if key==15 then
                                    hitbox[3]()
                                    hitbox[5]=true
                                    
                                    return
                                end
                            end)
                            
                            hook.add("inputReleased","hitId_"..i..self.name,function(key)
                                if key==15 then
                                    hitbox[5]=false
                                    
                                    hook.remove("inputReleased","hitId_"..i..self.name)
                                    
                                    return
                                end
                            end)
                        end
                    end
                else
                    if hitbox[4] then
                        hitbox[4]=false
     
                        hook.remove("inputPressed","hitId_"..i..self.name)
                    end
                end
            end
        end)
        
        self:play("https://cdn.discordapp.com/attachments/1120967741801762919/1148802726139023430/DING.WAV",0.5)
        
        return self
    end
    
    function window:edit(id)
        if player()!=owner() then
            return
        end
        
        net.start("cl_edit")
        net.writeTable({self.name,id})
        net.send()
    end
    
    function render.drawBorder(x,y,width,height,reverse)
        render.setColor(reverse and clr.black9 or clr.white)
        render.drawRectFast(x,y,1,height+1)
        render.drawRectFast(x,y,width+1,1)
        render.setColor(reverse and clr.white or clr.black9)
        render.drawRectFast(x+width,y,1,height+1)
        render.drawRectFast(x,y+height,width+1,1)
    end
    
    function render.drawTextEx(x,y,text,data)
        render.setColor(clr.black5)
        render.drawText(x,y,data.bold and string.gsub(text,text[1],string.upper(text[1]),1) or text)
        
        if data and data.bold then
            render.drawText(x,y,"_")
        end
    end
    
    function render.drawRectEx(x,y,width,height,data)
        mask(function()
            render.drawRectFast(x-1,y-1,width+3,height+3)
        end,function()
            render.setColor(Color(255,255,255))
            render.drawRectFast(x+1,y+1,width-1,height-1)
            
            render.setColor(Color(0,0,0))
            render.drawRectFast(x,y,1,height)
            render.drawRectFast(x,y,width,1)
            render.drawRectFast(x+width,y,1,height)
            
            render.setColor(clr.black9)
            render.drawRectFast(x-1,y-1,1,height+2)
            render.drawRectFast(x-1,y-1,width+2,1)
            render.drawRectFast(x,y+height,width+1,1)
            
            render.setColor(clr.white)
            render.drawRectFast(x+width+1,y-1,1,height+3)
            render.drawRectFast(x-1,y+height+1,width+2,1)
            
            render.setColor(clr.black5)
            
            if data and data.text then
                for i=1,#data.text do
                    if data.text[i] and data.text[i][1] then
                        local num=(#data.text+1)-i
                        
                        if data.color then
                            render.setColor(data.color)
                        end
                        
                        render.drawText(x+(#tostring(num)==1 and 5 or 3),y+(i-1)*9+2,string.replace(data.text[(#data.text+1)-i][1],"<line>",#tostring(num)==1 and num.." " or num))
                    end
                end
            end
        end)
    end
    
    function render.drawGroupOutline(x,y,width,height,text)
        render.setColor(Color(235,235,235))
        render.drawRectOutline(x+1,y+1,width,height,1)
        
        render.setColor(clr.black9)
        render.drawRectOutline(x,y,width,height,1)
    
        render.setColor(Color(192,192,192))
        render.drawRect(x+9,y,#text*4.3+2,2)
    
        render.setColor(clr.black5)
        render.drawText(x+10,y-5,text)
    end
    
    function render.contextMenu(x,y,width,height,data)
--[[
        for i, item in pairs(data.options)do 
            printConsole(table.toString(item))
        end
]]
    end
    
    function render.dropbox(x,y,width,height,data)
    end
    
    function window:drawButton(id,x,y,width,height,text,callBack)
        self:drawHitBox(id,x,y,width,height,callBack) --id,x,y,w,h,callBack
        
        render.drawBorder(x,y,width,height,self.hitboxes[id][5])
        
        if text then
            if type(text)=="string" then
                render.setColor(Color(0,0,0))
                render.drawText(x+width/2,y+height/2-5,text,1)
            else
                printConsole(type(text))
                render.setMaterial(text)
                render.drawTexturedRectUV(x+width/2,y+height/2-5,15,15,0,0,32/1024,32/1024)
            end
        end
    end
    
    function window:drawButtonToggle(id,x,y,width,height,data,callBack,bool,text)
        self:drawHitBox(id,x,y,width,height,callBack)
        
        if self.hitboxes[id][5] then
            render.setColor(clr.sliver)
            render.drawRectFast(x,y,width,height)
        end
        
        render.drawRectEx(x,y,width,height,data)
        
        if bool then
            render.setMaterial(icons.checkmark)
            render.drawTexturedRectUV(x,y-1,width+1,height+1,0,0,9/1024,9/1024)
        end
        
        if text then
            render.drawTextEx(x+15,y-1,text,data or {})
        end
    end
    
    function window:textBox(id,x,y,width,text)
        self:drawHitBox(id,x,y,width,10,function()
            self:edit(id)
        end)
        
        render.drawRectEx(x,y,width,10)
        
        render.setColor(clr.black5)
        render.drawText(x+2,y,self.hitboxes[id][6] or "")
    end

    function window:error(str)
        self.data.errors=self.data.errors+1
        
        local error=window:new(self.name.."_err"..self.data.errors,{
            x=self.data.cursor[1][1],
            y=self.data.cursor[1][2],
            width=300*2,
            height=100*2,
            size=3,
            --icon=render.createMaterial("https://cdn.discordapp.com/attachments/1120967741801762919/1145151102220771418/conn_dialup_recbin_phone.png")
        },self.renderer:getPos()+self.renderer:getUp()*2,self.renderer:getAngles())
    end
    
    function window:colorPalette(id,x,y,width,height,columns,rows,data)
        if !data then
            data={
                customRows=1,
                boxWidth=9,
                boxHeight=9
            }
        else
            data.customRows=data.customRows or 1
            data.boxWidth=data.boxWidth or 9
            data.boxHeight=data.boxHeight or 9
        end
        
        local rows=rows+1
        
        for i=1, columns do
            for ii=1, rows do
                local Clr=ii>rows-data.customRows and "blank" or Color(360/columns-i*360/columns-i,1,1.5-ii*1/(rows-data.customRows)):hsvToRGB()
                
                render.setColor(Clr!="blank" and Clr or Color(255,255,255))
                render.drawRectFast(x+(i-1)*(width/columns),y+(ii-1)*(height/rows),data.boxWidth,data.boxHeight)
                render.drawBorder(x+(i-1)*(width/columns)-1,y+(ii-1)*(height/rows)-1,data.boxWidth+1,data.boxHeight+1,true)

                self:drawHitBox(id+(i*ii),x+(i-1)*(width/columns),y+(ii-1)*(height/rows),data.boxWidth,data.boxHeight,function()
                    if Clr=="blank" then
                        local prompt=window:new(self.name.."_color"..i*ii,{
                            x=0,
                            y=0,
                            width=300*2,
                            height=200*2,
                            size=3,
                            title="Color"
                        },self.renderer:getPos()+self.renderer:getUp()*2+((self.renderer:getRight()*(self.data.cursor[1][2]/(75))))+((self.renderer:getForward()*(self.data.cursor[1][1]/(50)))),self.renderer:getAngles())
                        
                        prompt.paint=function()
                            render.drawTextEx(15,36,"Basic colors:",{
                                bold=true
                            })
                            
                            prompt:colorPalette(1,18,51,118,80,9,6,{
                                customRows=0,
                                boxHeight=8
                            })
                        end
                        
                        return
                    end
                    
                    self.data.user.color=Clr
                end)
            end
        end
    end
    
    function window:scrollBar(x,y,width,height,data)
    end
end