#!/usr/bin/env python3
# Gera assets/banners/parcerias.jpg com as logos de todos os parceiros (até 6 ou 9: 3 por linha; senão 4 por linha).
# Rodar na raiz do repositório: python3 scripts/banner-parceiros.py
# Para um parceiro novo, adicione a logo em assets/parceiros/ e uma linha em LOGOS.
from PIL import Image, ImageDraw, ImageFont, ImageFilter

# (arquivo, fundo do cartão) — None = a logo já tem fundo próprio e ocupa o cartão inteiro
LOGOS=[
  ('assets/parceiros/baruc.png',(24,27,42)),
  ('assets/parceiros/mylifedecor.png',None),
  ('assets/parceiros/camarote-do-corte.png',(24,27,42)),
  ('assets/parceiros/plant.jpg',None),
  ('assets/parceiros/tha-store.jpg',None),
  ('assets/parceiros/bea-toledo.png',(24,27,42)),
  ('assets/parceiros/riso-e-luz.jpg',None),
  ('assets/parceiros/hashtag-vistos.png',(24,27,42)),
  ('assets/parceiros/diane-oliveira.png',(255,255,255)),
  ('assets/parceiros/studio-start.png',(255,255,255)),
  ('assets/parceiros/cedro-clinic.jpg',None),
  ('assets/parceiros/emagrecentro.png',(255,255,255)),
  ('assets/parceiros/unic-beauty.jpg',None),
]

W,H=1600,900
im=Image.new('RGB',(W,H),(9,8,24))
glow=Image.new('L',(W,H),0); ImageDraw.Draw(glow).ellipse((1100,-400,2100,500),fill=40)
im=Image.composite(Image.new('RGB',(W,H),(40,44,80)),im,glow.filter(ImageFilter.GaussianBlur(160)))
px,py,pw,ph,r=0,50,830,850,190
mask=Image.new('L',(W,H),0); d=ImageDraw.Draw(mask)
d.rectangle((px,py+r,px+pw,py+ph),fill=255); d.rectangle((px,py,px+pw-r,py+ph),fill=255); d.pieslice((px+pw-2*r,py,px+pw,py+2*r),270,360,fill=255)
painel=Image.new('RGB',(W,H),(18,20,32))
grad=Image.new('L',(W,H)); gd=ImageDraw.Draw(grad)
for y in range(H): gd.line((0,y,W,y),fill=int(60*y/H))
painel=Image.composite(Image.new('RGB',(W,H),(10,11,18)),painel,grad)
im.paste(painel,(0,0),mask)

gap=22
por_linha=3 if len(LOGOS)<=6 or len(LOGOS)==9 else 4   # 9: grade 3x3; 7, 8 e 10+: 4 por linha
nl=-(-len(LOGOS)//por_linha)                 # linhas equilibradas: 10 vira 4+3+3, não 4+4+2
tam=[len(LOGOS)//nl+(1 if k<len(LOGOS)%nl else 0) for k in range(nl)]
linhas=[]; i=0
for t in tam: linhas.append(LOGOS[i:i+t]); i+=t
tile=min(236,(pw-60-(por_linha-1)*gap)//por_linha,(ph-120-(len(linhas)-1)*gap)//len(linhas))
gy=py+(ph-(len(linhas)*tile+(len(linhas)-1)*gap))//2
for li,linha in enumerate(linhas):
    tot=len(linha)*tile+(len(linha)-1)*gap; gx=px+(pw-tot)//2
    for k,(f,fundo) in enumerate(linha):
        x=gx+k*(tile+gap); y=gy+li*(tile+gap)
        lg=Image.open(f).convert('RGBA')
        m=Image.new('L',(tile,tile),0); ImageDraw.Draw(m).rounded_rectangle((0,0,tile-1,tile-1),30,fill=255)
        if fundo is None:
            im.paste(lg.resize((tile,tile),Image.LANCZOS).convert('RGB'),(x,y),m)
        else:
            im.paste(Image.new('RGB',(tile,tile),fundo),(x,y),m)
            s=tile-(24 if lg.width>1.6*lg.height else 56); lg.thumbnail((s,s),Image.LANCZOS)
            im.paste(lg,(x+(tile-lg.width)//2,y+(tile-lg.height)//2),lg)

av='/System/Library/Fonts/Avenir Next.ttc'
F=lambda s,i: ImageFont.truetype(av,s,index=i)
dr=ImageDraw.Draw(im)
def esp(t,x,y,f,fill,tr=6):
    for ch in t:
        dr.text((x,y),ch,font=f,fill=fill); x+=dr.textlength(ch,font=f)+tr
x0=965
esp('MEMBROS FONTE',x0,140,F(36,7),(245,245,246),7)
big=F(178,8); y=205
for linha in ['PAR','CEI','ROS']:
    dr.text((x0-8,y),linha,font=big,fill=(255,255,255)); y+=170
esp('BENEFÍCIOS EXCLUSIVOS',x0,y+40,F(34,7),(245,245,246),6)
esp('APRESENTE SUA CARTEIRINHA',x0,y+95,F(26,5),(122,212,207),5)
im.save('assets/banners/parcerias.jpg',quality=88,optimize=True)

# muda a versão das artes na home, para o navegador baixar o banner novo em vez de mostrar o antigo do cache
import re, time
home=open('index.html',encoding='utf-8').read()
home,n=re.subn(r"const BANNERS_V='[^']*';","const BANNERS_V='"+time.strftime('%Y%m%d-%H%M')+"';",home)
if n==1: open('index.html','w',encoding='utf-8').write(home)
else: print('aviso: BANNERS_V não encontrado em index.html')
print('ok', len(LOGOS), 'logos')
