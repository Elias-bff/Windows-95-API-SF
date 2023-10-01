--@name Testing Console demo
--@author Elias
--@include lib/win95_lib.lua

require("lib/win95_lib.lua")

if SERVER then
    net.receive("sv_log",function()
        wire.ports.Reset=1
        
        timer.simple(0.1,function()
            wire.ports.Reset=0
        end)
        
        net.start("cl_log")
        net.writeTable(net.readTable())
        net.send()
    end)

    net.receive("sv_sync",function()
        net.start("cl_"..net.readString())
        net.writeTable(net.readTable())
        net.send()
    end)
else
    local cursor=material.createFromImage("icon16/cursor.png","")
    local logger={}
    local data={
        logConnects=false,
        logEnts=false,
        logChat=true
    }
    
    for i=1,33 do
        logger[34-i]={"<line>"}
    end
        
    function log(text)
        for i=1,33 do
            logger[33-(i-1)]=logger[33-i]
        end
        
        logger[1]=text
    end
       
    local con=window:new("Test Console",{
        width=500*2,
        height=350*2,
        size=3,
        fonts={
            large=21.5,
            small=11.5
        },
        icon=render.createMaterial("https://cdn.discordapp.com/attachments/1120967741801762919/1145151102220771418/conn_dialup_recbin_phone.png")
    })
        
    net.receive("cl_log",function()
        log(net.readTable())
            
        con.hitboxes[4][6]=""
    end)
    
    net.receive("cl_logSync",function()
        local packet=net.readTable()
        
        if packet[1] then
            local random={"","A modest granite door in a dire marsh marks the entrance to this dungeon.","Beyond the granite door lies a grand, clammy room.","It's covered in large bones, small bones and crawling insects.","","Further ahead are two paths, you take the right.","Its twisted trail leads passed countless rooms and soon you enter a ragged area.","It's packed with boxes full of runes and magical equipment, as well as skeletons.","What happened in this place?","","You advance carefully onwards, deeper into the dungeon's secrets.","You pass many different passages, they all look so similar, this whole place is a maze.","You eventually make it to what is likely the final room.","A wide wooden door blocks your path.","Dire warning messages are all over it, somehow untouched by time and the elements.","You step closer to inspect it and.. wait.. did somebody just knock on the door?",""}
            
            for i=1,#random do
                timer.simple(i/8,function()
                    log({"<line> : "..random[i]})
                end)
            end
        end
        
        if packet[2] then
            local plys=table.add({""},find.allPlayers())
            plys[#plys+1]=""
            
            for i=1,#plys do
                timer.simple(i/8,function()
                    log({"<line> : "..(plys[i]=="" and "" or plys[i]:getName().." ; SteamID: "..plys[i]:getSteamID64())})
                end)
            end
        end
        
        if packet[3] then
            for i=1,33 do
                logger[34-i]={"<line>"}
            end
        end
    end)
    
    function syncSettings()
        net.start("sv_sync")
        net.writeString("logSettings")
        net.writeTable({data.logConnects,data.logEnts,data.logChat})
        net.send()
    end
    
    con.paint=function()
        render.drawGroupOutline(20,50,150,300,"Test panel")
        render.drawGroupOutline(30,65,129,85,"Buttons")
        render.drawGroupOutline(30,160,129,85,"Inputs")
        render.drawGroupOutline(30,255,129,85,"Settings")
    
        con:drawButton(1,38,75,108,18,"print random shit",function()
            net.start("sv_sync")
            net.writeString("logSync")
            net.writeTable({true,false,false})
            net.send()
        end)
        
        con:drawButton(2,38,98,108,18,"print all players",function()
            net.start("sv_sync")
            net.writeString("logSync")
            net.writeTable({false,true,false})
            net.send()
        end)
        
        con:drawButton(3,38,122,108,18,"clear log",function()
            net.start("sv_sync")
            net.writeString("logSync")
            net.writeTable({false,false,true})
            net.send()
        end)
        
        con:colorPalette(9,38,168,118,55,9,3)
        
        con:textBox(4,38,225,90)
        
        con:drawButton(5,131,224,20,12,"log",function()
            net.start("sv_log")
            net.writeTable({
                "<line>"..(con.hitboxes[4][6] or "")
            })
            net.send()
        end)
            
        con:drawButtonToggle(6,45,270,8,8,nil,function()
            data.logConnects=not data.logConnects
        
            syncSettings()
        end,data.logConnects,"Enable Connect Logs")
        
        con:drawButtonToggle(7,45,295,8,8,nil,function()
            data.logEnts=not data.logEnts
        
            syncSettings()
        end,data.logEnts,"Enable Entity Logging")
        
        con:drawButtonToggle(8,45,320,8,8,nil,function()
            data.logChat=not data.logChat
            
            syncSettings()
        end,data.logChat,"Enable Chat Logging")
            
        render.drawRectEx(180,50,325,300,{
            text=logger,
            color=con.data.user.color
        })
            
        render.drawTextEx(14,33,"sup",{
            bold=true
        })
    end
    
    syncSettings()
    
    net.receive("cl_logSettings",function()
        local packet=net.readTable()
        
        data.logConnects=packet[1]
        data.logEnts=packet[2]
        data.logChat=packet[3]
        
        if packet[1] then
            hook.add("PlayerConect","ConnectSync",function(id,name,id)
                log({"<line>: NET.ID: "..id.." ; Name: "..name.." ; STEAM ID: "..id})
            end)
        else
            hook.remove("PlayerConect","ConnectSync")
        end
        
        if packet[2] then
            hook.add("OnEntityCreated","EntSync",function(ent)
                log({"<line>: Class: "..ent:getClass().." ; Vector: "..table.toString(ent:getPos())})
            end)
        else
            hook.remove("OnEntityCreated","EntSync")
        end
        
        if packet[3] then
            hook.add("PlayerChat","chatSync",function(ply,text,_,dead)
                log({"<line>: "..(dead and "*DEAD*" or "")..ply:getName()..": "..text})
            end)
        else
            hook.remove("PlayerChat","chatSync")
        end
    end)
end