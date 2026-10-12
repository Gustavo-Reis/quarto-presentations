# Formatos de desenho encontrados

## A) Revit → PDF vetorial com keynotes (Almar L12, gabinete S+A)
- Texto extraível (PyMuPDF). Cada folha tem uma **legenda de keynotes**: `73.11.xx` móveis, `73.12.xx` equipamentos,
  com descrição completa e "Dimensões de 600mm de frente, 600mm de profundidade e 2400mm de altura".
- Etiquetas (tags) nas vistas com o código. **Só 1 módulo de cada tipo por parede é etiquetado** e há etiquetas em
  vistas laterais → contar etiquetas ≠ contar módulos. Daí `counting.py` (máx. por vista + preenchimento pelo MQT)
  e o passo de visão.
- Tipo da folha no carimbo: "MAPA DE COZINHAS TIPO 3" / "COZINHAS TIPO 8.1 (1/2)".
- Vistas: títulos "… - Cozinha - Planta", "… - Corte 01"; segmentação por componentes ligados da geometria.
- A ordem do texto na legenda varia por folha (código e descrição na mesma linha ou em linhas separadas) — o regex cobre ambos.

## B) ArchiCAD → DWF (Quinta do Pinhão L6, arq. Pedro Moura) — suportado
- DWF 6 = ZIP com um `.w2d` (binário WHIP!) por folha + `descriptor.xml` (nome da folha, papel em mm, transform).
- **`mob_quote/w2d.py`** lê o W2D em Python puro (sem compilar nada; corre no Windows da MOB). Os opcodes e os
  tamanhos dos operandos foram tirados do código-fonte do Autodesk DWF Toolkit (github.com/kveretennicov/dwf-toolkit,
  `develop/global/src/dwf/whiptk/*::materialize`). Pontos a saber:
  - coordenadas binárias são **relativas** ao ponto anterior (`l`, `p`, `0x10`, texto `x`/`0x18`…); `O` muda a origem;
  - strings: `'ascii'`, `"hex unicode"` ou `{int32 + UTF-16}`; o ASCII estendido `( … )` salta-se contando parênteses
    (atenção a `'…'` e a `{n bytes}` lá dentro);
  - a fonte (`0x06`) traz a altura e a **rotação** do texto (65 535 ≈ 0°, 16 383 = 90°, 49 151 = 270°);
  - as folhas não estão todas na mesma escala de unidades (Tipo 5: 100 un/mm de papel; as outras 1 000) — por isso a
    escala tira-se das próprias cotas, não do descriptor.
  - O leitor C++ antigo (`tools/dwf/`, compilado em Linux) fica só como referência.
- Não há códigos: cada módulo tem legenda em planta ("MI gaveteiro / 2 gavetas 1 porta talheres", "MS / 2 prateleiras",
  "MA. DESPENSA", "MI.MLL ENCASTRADA"…), nos layers "Textos 1:20" / "Texto 1:20", e a parede tem uma cadeia de
  **cotas** no layer "Cotagem 1-20 -1-50". Cada cota é um **segmento de linha próprio** ao longo da cadeia
  (36 491 → 39 491 = 3 000 un = 0,60 m a 1:20), o que dá larguras exatas. `dwf_extract.py`:
  - emparelha texto da cota ↔ segmento (1.ª passagem pelas cotas ≥ 0,30 m dá a escala; 2.ª exige comprimento compatível);
  - põe cada legenda na coluna da cadeia mais próxima que a cobre, preferindo cotas de móvel (≤ 1,25 m) à cota total;
  - divide uma cota partilhada por várias legendas do mesmo nível (frigorífico + arca sob "1,17");
  - ignora o **fogo vizinho**: as plantas mostram a cozinha do outro lado da parede, com legendas próprias.
- Armadilhas vistas: "MA. FRIGRORIFICO", "M I 2 prateleiras" que é um superior, "MI 1PRAT", torres "Forno e Micro-ondas"
  sem prefixo MA, "FORNO"/"MICROONDAS" soltos nos alçados (não são móveis), superiores sem legenda nos tipos 8 e 9.
- Tipos simétricos: o nome da folha diz quais ("6.1 COZINHA TIPO 1 & 1A", "6.3 … TIPO 3 e 3A").
- A folha "6.13 LAVANDARIAS" tem as 4 lavandarias numa só folha: 8 viewports (4 plantas + 4 cortes), cada planta
  com o título "Planta Lavandaria N" logo por baixo do canto inferior esquerdo do viewport — é assim que
  `_split_lavandarias()` as separa. As legendas trazem a largura ("MS 60 2 prat.", "MS 55 x 70", "M 110
  Lava-loiças") e parte delas está no layer "Rótulo 1:20" (lido só com prefixo de móvel + número). "MSR"/"MLR"
  são as máquinas de instalação livre (layer "3D - Cozinhas"). A Lav 3 só legenda o "MA 54": os restantes móveis
  só aparecem no corte.
- Também existem as mesmas folhas em PDF (ex.: "6.5 Cozinha TIPO 5.pdf"), com o mesmo conteúdo de texto.
