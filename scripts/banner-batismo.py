#!/usr/bin/env python3
# Gera assets/banners/batismo.jpg (arte do carrossel) a partir da foto assets/banners/batismo-foto.jpg.
# Rodar na raiz do repositório: python3 scripts/banner-batismo.py
# Com --telao <arquivo.jpg> gera também a versão 1920x1080 para o telão da igreja.
# Para outro batismo, troque DATA/DIA abaixo (e a foto, se quiser) e rode de novo.
import sys, re, time
from PIL import Image, ImageDraw, ImageFont, ImageFilter

DATA, DIA = '29/11', 'DOMINGO'
FOTO = 'assets/banners/batismo-foto.jpg'

def arte(k=1.0):
    n=lambda v:int(round(v*k))
    W,H=n(1600),n(900)
    im=Image.new('RGB',(W,H),(9,8,24))
    glow=Image.new('L',(W,H),0); ImageDraw.Draw(glow).ellipse((n(1100),n(-400),n(2100),n(500)),fill=40)
    im=Image.composite(Image.new('RGB',(W,H),(40,44,80)),im,glow.filter(ImageFilter.GaussianBlur(n(160))))
    # painel da foto: encosta na esquerda e embaixo, canto de cima à direita arredondado
    px,py,pw,ph,r=0,n(50),n(830),n(850),n(190)
    mask=Image.new('L',(W,H),0); d=ImageDraw.Draw(mask)
    d.rectangle((px,py+r,px+pw,py+ph),fill=255); d.rectangle((px,py,px+pw-r,py+ph),fill=255); d.pieslice((px+pw-2*r,py,px+pw,py+2*r),270,360,fill=255)
    foto=Image.open(FOTO).convert('RGB')
    esc=max(pw/foto.width,ph/foto.height); foto=foto.resize((int(foto.width*esc+1),int(foto.height*esc+1)),Image.LANCZOS)
    fx,fy=(foto.width-pw)//2,(foto.height-ph)//2
    camada=Image.new('RGB',(W,H)); camada.paste(foto.crop((fx,fy,fx+pw,fy+ph)),(px,py))
    im.paste(camada,(0,0),mask)

    av='/System/Library/Fonts/Avenir Next.ttc'
    F=lambda s,i: ImageFont.truetype(av,n(s),index=i)
    dr=ImageDraw.Draw(im)
    def esp(t,x,y,f,fill,tr=6):
        for ch in t:
            dr.text((x,y),ch,font=f,fill=fill); x+=dr.textlength(ch,font=f)+n(tr)
    x0=n(965)
    esp(DATA+'  |  '+DIA,x0,n(135),F(36,7),(245,245,246),6)
    big=F(178,8); y=n(205)
    for linha in ['BA','TIS','MO']:
        dr.text((x0-n(8),y),linha,font=big,fill=(255,255,255)); y+=n(170)
    esp('INSCRIÇÕES ABERTAS',x0,y+n(40),F(34,7),(245,245,246),6)
    esp('ÚLTIMO DOMINGO DO MÊS',x0,y+n(95),F(26,5),(170,172,186),5)
    return im

arte().save('assets/banners/batismo.jpg',quality=88,optimize=True)
if '--telao' in sys.argv:
    saida=sys.argv[sys.argv.index('--telao')+1]
    arte(1.2).save(saida,quality=92,optimize=True); print('telão:',saida)

# muda a versão das artes na home, para o navegador baixar o banner novo em vez de mostrar o antigo do cache
home=open('index.html',encoding='utf-8').read()
home,q=re.subn(r"const BANNERS_V='[^']*';","const BANNERS_V='"+time.strftime('%Y%m%d-%H%M')+"';",home)
if q==1: open('index.html','w',encoding='utf-8').write(home)
else: print('aviso: BANNERS_V não encontrado em index.html')
print('ok')
