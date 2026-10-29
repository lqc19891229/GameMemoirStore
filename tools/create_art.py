"""Rebuild original pixel artwork. Requires Pillow; not needed to run the game."""
from pathlib import Path
import random
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parents[1] / 'assets' / 'art'
OUT.mkdir(parents=True, exist_ok=True)

def stars(d, seed, colors):
    r = random.Random(seed)
    for _ in range(90):
        x, y = r.randrange(320), r.randrange(90)
        d.point((x, y), fill=r.choice(colors))
        if r.random() < .1:
            d.line((x-1,y,x+1,y), fill=colors[0])
            d.line((x,y-1,x,y+1), fill=colors[0])

def figure(d,x,y,coat='#bc765b'):
    d.rectangle((x+2,y,x+5,y+3), fill='#d4bd93')
    d.rectangle((x,y+4,x+6,y+12), fill=coat)
    d.rectangle((x,y+12,x+2,y+17), fill='#1a2935')
    d.rectangle((x+5,y+12,x+7,y+17), fill='#1a2935')
    d.line((x+5,y+5,x+17,y+7),fill='#e0a364',width=2)

def make(kind):
    im=Image.new('RGB',(320,128));d=ImageDraw.Draw(im)
    if kind=='stars':
        d.rectangle((0,0,320,128),fill='#101d32')
        for y,c in [(34,'#162a40'),(58,'#1b3648'),(78,'#244654'),(98,'#3b5b60')]:
            d.rectangle((0,y,320,128),fill=c)
        stars(d,2,['#b9d5d0','#50798a','#d7bb83'])
        d.ellipse((219,5,275,61), fill='#c1b98d')
        d.ellipse((229,0,283,54), fill='#162a40')
        d.polygon([(0,93),(35,79),(58,85),(90,68),(117,84),(152,72),(183,91),(224,79),(268,93),(320,73),(320,128),(0,128)],fill='#29404b')
        d.polygon([(0,108),(37,100),(72,106),(104,89),(143,104),(174,101),(203,109),(238,95),(277,101),(320,91),(320,128),(0,128)],fill='#182e3a')
        d.rectangle((200,67,241,103),fill='#18343e')
        d.rectangle((196,65,246,69),fill='#527a78')
        d.rectangle((207,76,216,91),fill='#bbaa77');d.rectangle((222,76,231,91),fill='#476f72')
        d.rectangle((217,45,220,65),fill='#688c88')
        d.polygon([(207,42),(234,42),(229,52),(213,52)],fill='#718c83')
        d.line((220,33,220,44),fill='#dfba7a',width=1)
        d.polygon([(0,121),(23,114),(58,117),(86,109),(112,116),(151,114),(178,121),(221,115),(259,118),(291,110),(320,113),(320,128),(0,128)],fill='#0c1a25')
        figure(d,259,94)
        r=random.Random(81)
        for _ in range(60):
            x=r.randrange(320);y=r.randrange(113,128);d.rectangle((x,y,x+2,y),fill='#294450')
    elif kind=='desert':
        d.rectangle((0,0,320,128),fill='#8c5641')
        d.rectangle((0,38,320,128),fill='#b57c4e')
        d.ellipse((240,11,280,51),fill='#efcd81')
        d.polygon([(0,80),(54,49),(76,65),(111,49),(164,81),(222,67),(277,83),(320,70),(320,128),(0,128)],fill='#7f5140')
        d.polygon([(0,106),(88,85),(155,102),(209,82),(320,103),(320,128),(0,128)],fill='#bb8d5b')
        for x,y,w,h in [(94,66,31,34),(130,55,40,49),(174,74,43,27)]:
            d.rectangle((x,y,x+w,y+h),fill='#39444b');d.rectangle((x,y,x+w,y+4),fill='#66706a')
            for wx in range(x+6,x+w-3,9):d.rectangle((wx,y+10,wx+3,y+16),fill='#d6ad68')
        d.rectangle((149,35,151,55),fill='#293b42');d.line((143,36,158,36),fill='#e0b56b',width=2)
        d.polygon([(31,109),(35,100),(49,100),(55,107),(72,108),(72,114),(30,114)],fill='#36454b')
        for x in [37,59]:d.ellipse((x,110,x+8,117),fill='#1b2e37')
        d.line((0,124,320,124),fill='#77533f',width=3)
    elif kind=='valley':
        d.rectangle((0,0,320,128),fill='#a8c6a5')
        d.polygon([(0,64),(54,22),(86,61),(139,13),(199,61),(251,27),(320,63),(320,128),(0,128)],fill='#658c79')
        d.polygon([(0,84),(71,54),(137,84),(217,48),(320,81),(320,128),(0,128)],fill='#476f60')
        d.rectangle((0,91,320,128),fill='#7e9b64')
        d.polygon([(158,128),(183,91),(196,91),(187,128)],fill='#c3b382')
        d.rectangle((199,77,249,105),fill='#d0bc8f');d.polygon([(192,78),(222,56),(256,78)],fill='#9b6150')
        d.rectangle((219,87,230,105),fill='#695749')
        d.rectangle((204,85,212,92),fill='#d9ddae');d.rectangle((236,85,244,92),fill='#d9ddae')
        for x,y in [(22,75),(58,81),(283,76),(112,87)]:
            d.rectangle((x,y,x+4,y+24),fill='#685b45');d.rectangle((x-8,y-7,x+12,y+10),fill='#345d4a');d.rectangle((x-5,y-12,x+9,y),fill='#476f50')
        for y in [103,112,121]:
            d.rectangle((86,y,151,y+4),fill='#877347')
            for x in range(90,151,9):d.line((x,y-3,x,y),fill='#bfd18a',width=2)
    elif kind=='ocean':
        d.rectangle((0,0,320,128),fill='#608b96')
        d.rectangle((0,57,320,128),fill='#366d7d')
        d.rectangle((0,80,320,128),fill='#28536a')
        for y in range(65,128,7):
            for x in range((y*3)%45,320,51):d.line((x,y,x+21,y),fill='#69979a')
        d.polygon([(167,128),(184,94),(204,89),(222,72),(253,88),(278,97),(294,128)],fill='#203e4b')
        d.rectangle((226,35,238,85),fill='#dad4b2');d.rectangle((226,57,238,65),fill='#a45e4f')
        d.rectangle((222,30,242,37),fill='#273d49');d.rectangle((225,24,239,29),fill='#e4c578')
        d.polygon([(232,24),(200,3),(269,3)],fill='#e0c77b')
        d.polygon([(37,84),(66,84),(59,91),(44,91)],fill='#b98f63');d.line((51,64,51,84),fill='#d2cfb3',width=2)
        d.polygon([(53,65),(53,81),(65,80)],fill='#d4d6be')
    elif kind=='castle':
        d.rectangle((0,0,320,128),fill='#282843');stars(d,45,['#a99cbd','#656385','#c9b598'])
        d.ellipse((46,9,81,44),fill='#c2b7b0')
        d.rectangle((0,92,320,128),fill='#171f32')
        for x,y,w in [(130,44,24),(158,61,46),(208,31,24),(237,57,28)]:
            d.rectangle((x,y,x+w,107),fill='#42405b')
            d.polygon([(x-3,y),(x+w//2,y-22),(x+w+3,y)],fill='#20283f')
            for yy in range(y+10,100,19):d.rectangle((x+8,yy,x+12,yy+8),fill='#b99c75')
        d.rectangle((177,85,190,110),fill='#101a2a');d.arc((177,78,190,94),180,360,fill='#b29374',width=2)
        d.polygon([(154,128),(177,109),(190,109),(214,128)],fill='#676073')
        figure(d,171,106,coat='#819d98')
    elif kind=='train':
        d.rectangle((0,0,320,128),fill='#d9b28c');d.ellipse((242,11,277,46),fill='#f1d69b')
        d.polygon([(0,70),(65,35),(123,69),(195,31),(259,67),(320,43),(320,128),(0,128)],fill='#8a8980')
        d.polygon([(0,87),(85,59),(161,85),(230,62),(320,86),(320,128),(0,128)],fill='#657e70')
        d.rectangle((0,108,320,128),fill='#554e49');d.line((0,117,320,117),fill='#b1a58b',width=2)
        for x in range(0,320,12):d.line((x,119,x+4,125),fill='#302f36',width=2)
        d.rectangle((55,69,252,105),fill='#b5684f');d.rectangle((53,65,253,72),fill='#3f5357')
        d.rectangle((55,91,252,96),fill='#dcb47c')
        for x in range(64,237,23):d.rectangle((x,76,x+15,88),fill='#a4c0b1')
        for x in range(68,246,39):d.ellipse((x,102,x+13,112),fill='#293c45')
        d.rectangle((0,105,33,110),fill='#6d6755');d.rectangle((11,54,14,108),fill='#35494e');d.line((0,53,71,53),fill='#35494e',width=3)
    im.save(OUT / f'{kind}.png')

for kind in ['stars','desert','valley','ocean','castle','train']:make(kind)

im=Image.new('RGBA',(32,32));d=ImageDraw.Draw(im)
d.rectangle((3,3,27,23),fill='#a2c69b');d.rectangle((6,6,24,18),fill='#203c46')
d.rectangle((9,9,21,15),fill='#b4d3a9');d.rectangle((12,23,18,26),fill='#7b9d82');d.rectangle((7,27,24,29),fill='#a2c69b')
d.rectangle((8,20,11,21),fill='#547866');d.point((23,20),fill='#f0ce8d')
im.save(OUT/'icon.png')

im=Image.new('RGB',(1280,800),'#111e28');d=ImageDraw.Draw(im)
for x in range(0,1280,24):
    for y in range(0,800,24):d.point((x,y),fill='#1b2b33')
im.save(OUT/'background.png')
print('Created 8 original pixel assets.')
