"""Generate an editor-editable native Godot scene and theme. Python stdlib only."""
from pathlib import Path
import json

ROOT=Path(__file__).resolve().parents[1]
def q(value):return json.dumps(value,ensure_ascii=False)
def color(s):
    s=s.lstrip('#');v=[int(s[i:i+2],16)/255 for i in range(0,len(s),2)]
    if len(v)==3:v.append(1)
    return 'Color('+', '.join(f'{n:.5f}' for n in v)+')'

palette={'text':'#dde4d9','muted':'#849995','faint':'#526c71','gold':'#d9b77c','green':'#b3ce8f','teal':'#84b6ab'}
styles={
    'panel':('#1a2c36','#354b51',1), 'deep':('#14232e','#30434a',1),
    'button':('#233942','#40575b',1),'hover':('#304a50','#8eb2a1',1),
    'pressed':('#35594f','#a7c899',1),'disabled':('#1b2a33','#304149',1),
    'active':('#2b4947','#91b5a0',1),'green':('#b3ce8f','#d7e5b8',1),
    'green_hover':('#c8dca5','#edf2d8',1),'green_down':('#94b37a','#bbd299',1),
    'cart':('#29443f','#80a389',1),'toast':('#2f4e46','#a9c793',1),
    'focus':('#00000000','#e8ca90',2),'transparent':('#00000000','#00000000',0),
}
theme=['[gd_resource type="Theme" load_steps=18 format=3]',
       '[ext_resource type="FontFile" path="res://assets/fonts/ArkPixel12.ttf" id="font"]']
for name,(bg,border,width) in styles.items():
    theme.extend([f'[sub_resource type="StyleBoxFlat" id="{name}"]',f'bg_color = {color(bg)}',
                  f'border_color = {color(border)}',*[f'border_width_{side} = {width}' for side in ['left','top','right','bottom']],
                  'content_margin_left = 12.0','content_margin_right = 12.0','content_margin_top = 6.0','content_margin_bottom = 6.0'])
theme.extend(['[resource]','default_font = ExtResource("font")','default_font_size = 12',
              f'Button/colors/font_color = {color(palette["text"])}',f'Button/colors/font_hover_color = {color("#edf1de")}',
              f'Button/colors/font_disabled_color = {color("#607571")}',
              'Button/styles/normal = SubResource("button")','Button/styles/hover = SubResource("hover")',
              'Button/styles/pressed = SubResource("pressed")','Button/styles/disabled = SubResource("disabled")',
              'Button/styles/focus = SubResource("focus")',f'Label/colors/font_color = {color(palette["text"])}',
              'Panel/styles/panel = SubResource("panel")',
              'LineEdit/styles/normal = SubResource("deep")','LineEdit/styles/focus = SubResource("hover")',
              f'LineEdit/colors/font_color = {color(palette["text"])}',f'LineEdit/colors/font_placeholder_color = {color("#6f8585")}',
              f'LineEdit/colors/caret_color = {color(palette["green"])}',
              'VScrollBar/styles/scroll = SubResource("deep")','VScrollBar/styles/grabber = SubResource("button")',
              'VScrollBar/styles/grabber_highlight = SubResource("hover")','VScrollBar/styles/grabber_pressed = SubResource("active")'])
(ROOT/'assets/store_theme.tres').write_text('\n\n'.join(theme)+'\n')

ext=[('Script','res://scripts/store.gd','script'),('Theme','res://assets/store_theme.tres','theme')]
ext += [('Texture2D',f'res://assets/art/{name}.png',name) for name in ['icon','background','stars','desert','valley','ocean']]
parts=[]
def node(name,typ,parent,rect=None,props=None,unique=False):
    p=[f'[node name="{name}" type="{typ}"'+(f' parent="{parent}"' if parent is not None else '')+']']
    if unique:p.append('unique_name_in_owner = true')
    if rect:
        x,y,w,h=rect;p.extend([f'offset_left = {float(x)}',f'offset_top = {float(y)}',f'offset_right = {float(x+w)}',f'offset_bottom = {float(y+h)}'])
    for k,v in (props or {}).items():p.append(f'{k} = {v}')
    parts.append('\n'.join(p));return name if parent=='.' else f'{parent}/{name}' if parent else '.'
def label(name,parent,rect,text,size=12,tint='text',unique=False,wrap=False,extra=None):
    p={'mouse_filter':'2','text':q(text),'theme_override_font_sizes/font_size':str(size),'theme_override_colors/font_color':color(palette.get(tint,tint)),'vertical_alignment':'1'}
    if wrap:p.update({'autowrap_mode':'2'})
    p.update(extra or {});return node(name,'Label',parent,rect,p,unique)
def panel(name,parent,rect,style='panel',unique=False):
    return node(name,'Panel',parent,rect,{'theme_override_styles/panel':f'SubResource("{style}")'},unique)
def button(name,parent,rect,text,style=None,unique=True,extra=None):
    p={'text':q(text),'mouse_default_cursor_shape':'2'}
    if style:p['theme_override_styles/normal']=f'SubResource("{style}")'
    if style=='green':
        p.update({'theme_override_styles/hover':'SubResource("green_hover")','theme_override_styles/pressed':'SubResource("green_down")','theme_override_colors/font_color':color('#20352f'),'theme_override_colors/font_hover_color':color('#18302b'),'theme_override_colors/font_pressed_color':color('#20352f')})
    p.update(extra or {});return node(name,'Button',parent,rect,p,unique)
def art(name,parent,rect,texture,unique=False):
    return node(name,'TextureRect',parent,rect,{'texture':f'ExtResource("{texture}")','expand_mode':'1','stretch_mode':'0','texture_filter':'1','mouse_filter':'2'},unique)
def line(name,parent,rect,tint='#30434a'):
    node(name,'ColorRect',parent,rect,{'color':color(tint),'mouse_filter':'2'})

node('MemoirStore','Control',None,None,{'layout_mode':'3','anchors_preset':'15','anchor_right':'1.0','anchor_bottom':'1.0','grow_horizontal':'2','grow_vertical':'2','theme':'ExtResource("theme")','script':'ExtResource("script")'})
art('Background','.',(0,0,1280,800),'background')
line('Chrome','.',(0,0,1280,28),'#0c1720')
label('WindowTitle','.',(24,0,650,28),'GAME MEMOIR  /  游戏回忆录',12,'muted')
button('AboutButton','.',(1156,4,56,20),'关于','transparent')
button('QuitButton','.',(1220,4,36,20),'×','transparent',extra={'tooltip_text':q('退出游戏，当前收藏会自动保存')})

art('BrandIcon','.',(30,52,48,48),'icon')
label('BrandName','.',(94,45,220,36),'游戏回忆录',24)
label('BrandSub','.',(96,83,230,20),'A LIBRARY OF YOUR OWN',12,'muted')
button('StoreTab','.',(378,60,84,36),'商 店','active')
button('LibraryTab','.',(474,60,96,36),'游戏库','transparent')
button('WishTab','.',(582,60,108,36),'愿望单','transparent')
label('OnlineDot','.',(904,57,24,32),'●',12,'green')
label('PlayerName','.',(930,53,112,24),'像素收藏家',12)
label('PlayerSub','.',(930,77,112,20),'每一段回忆都算数',12,'muted')
panel('WalletPanel','.',(1072,50,176,54),'deep')
label('WalletTitle','WalletPanel',(12,5,70,18),'可用预算',12,'muted')
label('WalletValue','WalletPanel',(12,25,152,22),'160 点',24,'green',True)
line('HeaderRule','.',(32,124,1216,1))

side=panel('Sidebar','.',(32,154,164,585),'deep')
label('SidebarTitle',side,(16,15,132,20),'你的游戏年代',12,'muted')
label('DateLabel',side,(16,43,140,28),'2003 年 09 月',12,'gold',True)
line('SideRule1',side,(16,85,132,1))
label('BrowseLabel',side,(16,101,132,20),'浏览商店',12,'muted')
for i,(n,t) in enumerate([('FilterAll','全部游戏'),('FilterSale','正在优惠'),('FilterAdventure','探索冒险'),('FilterStrategy','策略战术'),('FilterLife','生活模拟'),('FilterComing','即将推出')]):
    button(n,side,(12,133+i*37,140,31),t,'active' if i==0 else 'transparent',extra={'alignment':'0'})
line('SideRule2',side,(16,365,132,1))
label('MonthlyTitle',side,(16,385,132,22),'每月的小小期待',12,'gold')
label('MonthlyText',side,(16,415,132,64),'每月预算 +60 点\n新作陆续上架\n慢慢收藏，慢慢玩',12,'muted',wrap=True)
button('NextMonthButton',side,(12,500,140,36),'进入下个月  >')
label('DemoMonth',side,(16,547,132,22),'商店场景 · 6个月演示',12,'faint')

label('PageEyebrow','.',(224,151,680,20),'THE STORE  /  商店',12,'teal',True)
label('PageHeading','.',(224,177,730,32),'发现你的下一段回忆',24,unique=True)
node('SearchBox','LineEdit','.',(960,173,288,34),{'unique_name_in_owner':'true','placeholder_text':q('搜索游戏 / 制作组'),'clear_button_enabled':'true','max_length':'50'},True)

hero=panel('Hero','.',(224,229,1024,252),'panel',True)
heroart=button('HeroInspect',hero,(0,0,646,252),'','transparent',extra={'tooltip_text':q('查看《远星来信》详情')})
art('HeroArt',heroart,(1,1,644,250),'stars')
line('ArtShade',heroart,(1,1,644,250),'#07121a30')
panel('HeroBadge',heroart,(24,21,108,24),'deep')
label('HeroBadgeText',heroart+'/HeroBadge',(8,0,96,24),'本月编辑精选',12,'gold')
label('HeroEnglish',heroart,(24,71,580,24),'LETTERS FROM THE STARS',12,'#c2d2bf')
label('HeroTitle',heroart,(22,100,580,55),'远星来信',36,'#eef0d4')
label('HeroTagline',heroart,(24,197,580,32),'在漫长的星夜里，寻找一封迟到的信。',12,'#cad9cf')
line('HeroSeam',hero,(646,0,1,252),'#45605c')
label('HeroMini',hero,(666,16,335,22),'一封来自宇宙边境的邀请',12,'gold')
label('HeroDescription',hero,(666,48,335,64),'穿过静默的观测站与漫长的星夜，\n重新连接散落在宇宙里的故事。',12,'text',wrap=True)
label('HeroGenres',hero,(666,113,335,20),'探索冒险  /  科幻  /  剧情',12,'muted')
label('HeroReview',hero,(666,140,335,20),'好评如潮  ·  268 条玩家评价',12,'teal')
panel('DiscountBlock',hero,(666,175,56,24),'cart')
label('DiscountText',hero+'/DiscountBlock',(5,0,46,24),'-25%',12,'green')
label('HeroOldPrice',hero,(734,174,75,24),'原价 88',12,'muted')
label('HeroPrice',hero,(828,172,170,28),'66 点',24,'green',True,extra={'horizontal_alignment':'2'})
button('HeroAdd',hero,(666,210,224,30),'加入购物车','green')
button('HeroWish',hero,(900,210,104,30),'+ 愿望单')

label('SectionTitle','.',(224,504,500,25),'本月精选',12,unique=True)
label('ResultCount','.',(720,505,280,24),'4 款游戏等待与你相遇',12,'muted',True,extra={'horizontal_alignment':'2'})
button('PrevButton','.',(1020,503,36,26),'<')
label('PageLabel','.',(1064,504,108,24),'01 / 01',12,'muted',True,extra={'horizontal_alignment':'1'})
button('NextButton','.',(1180,503,36,26),'>')

for i,(title,genre,price,texture) in enumerate([('远星来信','探索冒险 · 科幻','66 点','stars'),('钢铁边境','策略战术 · 单人','72 点','desert'),('雾谷手记','生活模拟 · 田园','38 点','valley'),('最后一座灯塔','探索冒险 · 解谜','60 点','ocean')]):
    card=button(f'Card{i}','.',(224+i*260,542,244,178),'',unique=True)
    art(f'CardArt{i}',card,(1,1,242,96),texture,True)
    label(f'CardTitle{i}',card,(12,105,220,22),title,12,unique=True)
    label(f'CardGenre{i}',card,(12,129,220,20),genre,12,'muted',True)
    label(f'CardPrice{i}',card,(12,151,220,22),price,12,'green',True,extra={'horizontal_alignment':'2'})

label('EmptyResults','.',(246,564,955,104),'还没有游戏。',24,'muted',True,extra={'visible':'false','horizontal_alignment':'1'})
label('CollectionStatus','.',(224,738,640,28),'游戏库 0 款   /   愿望单 0 款',12,'muted',True)
button('CartButton','.',(1020,736,228,34),'购物车  0','cart')
line('FooterBG','.',(0,780,1280,20),'#0c1720')
label('FooterLeft','.',(32,780,880,20),'游戏回忆录 · 商店场景   /   虚构目录，供场景体验使用',12,'faint')
label('FooterRight','.',(906,780,342,20),'Esc 返回  ·  Ctrl+F 搜索  ·  F11 全屏',12,'muted',extra={'horizontal_alignment':'2'})

node('ModalShade','ColorRect','.',(0,0,1280,800),{'color':color('#050d18dd'),'visible':'false'},True)
detail=panel('DetailPanel','ModalShade',(300,106,680,590),'panel',True)
label('DetailCaption',detail,(24,11,550,24),'游戏详情',12,'muted')
button('DetailClose',detail,(620,10,36,26),'×','transparent')
art('DetailArt',detail,(24,52,632,188),'stars',True)
label('DetailTitle',detail,(24,253,632,40),'远星来信',24,unique=True)
label('DetailMeta',detail,(24,302,632,24),'探索冒险 / 微光工作室',12,'teal',True)
label('DetailDescription',detail,(24,340,632,78),'',12,'text',True,True)
label('DetailInfo',detail,(24,427,632,54),'',12,'muted',True,True)
label('DetailPrice',detail,(24,493,210,30),'66 点',24,'green',True)
button('DetailWish',detail,(24,538,204,32),'+ 加入愿望单')
button('DetailAdd',detail,(244,538,412,32),'加入购物车','green')

cart=panel('CartPanel','ModalShade',(330,130,620,540),'panel',True)
label('CartTitle',cart,(24,15,520,30),'你的购物车',24,unique=True)
button('CartClose',cart,(560,16,36,26),'×','transparent')
node('CartScroll','ScrollContainer',cart,(24,64,572,324),{'horizontal_scroll_mode':'0'},True)
node('CartRows','VBoxContainer',cart+'/CartScroll',None,{'unique_name_in_owner':'true','size_flags_horizontal':'3','theme_override_constants/separation':'12'},True)
line('CartRule',cart,(24,400,572,1))
label('CartSummary',cart,(24,414,572,46),'',12,'text',True,True)
button('CheckoutButton',cart,(24,474,572,40),'确认购买','green')

about=panel('AboutPanel','ModalShade',(370,170,540,460),'panel',True)
label('AboutTitle',about,(24,16,460,40),'游戏回忆录',24)
button('AboutClose',about,(480,18,36,26),'×','transparent')
label('AboutBody',about,(24,80,492,276),'像素风格 · 游戏收藏经营模拟\n\n这是可独立运行的商店场景。\n浏览游戏、加入愿望单、购物车结算，\n然后在游戏库中欣赏你的第一批收藏。\n\n本场景采用虚构作品与演示发行日期，\n暂不代表正式的历史上架年表。\n\n购买与收藏会自动保存到本地。\n像素字体：Ark Pixel / SIL OFL 1.1',12,'muted',wrap=True)
button('ResetButton',about,(24,378,492,38),'重置演示存档')

toast=panel('Toast','.',(340,724,600,44),'toast',True)
parts[-1]+='\nvisible = false\nmouse_filter = 2'
label('ToastText',toast,(12,4,576,36),'已加入购物车',12,'text',True,True,{'horizontal_alignment':'1'})

subs=[]
for name,(bg,border,width) in styles.items():
    subs.append('\n'.join([f'[sub_resource type="StyleBoxFlat" id="{name}"]',f'bg_color = {color(bg)}',f'border_color = {color(border)}',*[f'border_width_{side} = {width}' for side in ['left','top','right','bottom']]]))
header=[f'[gd_scene load_steps={len(ext)+len(subs)+1} format=3]']
header += [f'[ext_resource type="{typ}" path="{path}" id="{name}"]' for typ,path,name in ext]
(ROOT/'scenes/legacy_store.tscn').write_text('\n\n'.join(header+subs+parts)+'\n')
print(f'Wrote legacy_store.tscn with {len(parts)} editable nodes.')
