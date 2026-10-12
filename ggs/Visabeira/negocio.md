# Processo de orçamentação MOB (o que foi aprendido)

## Entrada do cliente (empreiteiro / dono de obra)
- **MQT** (mapa de quantidades) do concurso. As cozinhas aparecem como artigos por tipologia:
  - Almar L12 (art. 5.17.1.x): "Cozinha tipo 1 · Bancada c/ 2,74x0,60x0,88m · Móveis superiores c/ 2,74x0,40x0,90m ·
    Móveis altos c/ 3,00x0,60x2,40m · Armários AQS c/ 0,80x0,80x2,40m" | 2 | un. Tampos noutro artigo (5.17.2.x),
    lava-loiça (5.17.3) e torneira (5.17.4) à parte. **Sem eletrodomésticos.**
  - Quinta do Pinhão L6 (art. 11.3.x): "Cozinha 3A com ilha (simétrica de 3)" | cj | Quant. ABC | Quant. DEF | Totais.
    Sem dimensões nem eletrodomésticos; lavandarias/tratamento de roupa em 11.4.x.
- **Peças desenhadas** por tipo de cozinha: planta, planta de tetos e 2–6 alçados (cortes) a 1:20.
  O MQT não se pode alterar (texto nem quantidades) — o preço entra nas colunas de preço.

## Proposta MOB (exemplo real: QUO16519, Almar L12, 09/07/2024)
Folha "Resumo da proposta":
| Bloco | Cálculo |
|---|---|
| Cozinhas (11 tipologias) | `PU = Base × 1,15 + Montagem/(1−50%)`; desconto 50% ⇒ líquido = Base×0,575 + Montagem |
| Acessórios | porta-talheres NICK 600 (42) / 700 (20), balde LINE 292 (62), misturadora Bruma Ginger (62), lava-loiça Teka (62) — descontos 20–40% |
| Eletrodomésticos | forno, placa, micro, exaustor Teka × 62 — desconto 22% |
| Tampos | 0 € — **não incluídos** ("Não incluídos" na folha, e 0,00 € também nos orçamentos ecadpro) |
| Total | 564 224,76 € + IVA 23% = 693 996,45 € |

Observações:
- Tipos 8 e 8.1 com preço igual (MOB tratou-os como iguais).
- Porta-talheres 700 = cozinhas com gaveta de 750 (Tipo 8) + 8.1 (assumida igual).
- Exaustor trocado (ref. do projeto não era de encastre).
- "Foi nossa intenção proceder à distribuição dos móveis…" → a MOB pode redesenhar a cozinha.

## Os orçamentos ecadpro (a peça que faltava)
A pasta `1-ORCAMENTO/` do pedido traz, por tipologia, um PDF **"MOB - Orçamento"** exportado do ecadpro
(`file_C_evolution_Mob__ecadpro_ordini_0031NN_MOB.pdf`, 9 dos 11 tipos — 8 e 8.1 só têm imagens).
É a lista de módulos real da MOB, com referência, dimensão e preço à tarifa interna ("modello=999-Lista
Preços 3"). `mob_quote/ecadpro.py` lê-os; `tests/fixtures/almar_mob_ecadpro.json` guarda o resultado.

**O TOTAL ILÍQUIDO de cada export é exatamente a "Base" da tipologia** (Tipo 4 = 13 630,68 €,
Tipo 6 = 7 969,48 €, …, nos 9 ao cêntimo).

### 1. O fator tabela → base é 0,385
O preço "999" da MOB a dividir pelo preço da `data/lista_precos_mob.xlsx` (grupo 9) dá **0,385 constante**:
`MIG21600803580` 503,25/1 307 · `MS600903330` 307,89/800 · `MILDFS700803580` 401,61/1 043 ·
`MICL1240803580` 355,74/924 · `MSD800903330` 407,88/1 059 · `MIL400803580` 241,56/627.

O 0,512 que o projeto usava era `0,385 × 1,33` — estava inflacionado para tapar o que vem a seguir.

**A MOB indicou 0,363** ("o coeficiente multiplicador para esse orçamento é 0.363, depois disso tem
condições comerciais"). Não é contradição: a QUO16519 é de 06/2024 e a `lista_precos_mob.xlsx` que
temos foi atualizada em 09/2026 — `0,363 × 1,06 = 0,3848`, ou seja um aumento de tabela de 6%
reconcilia os dois ao terceiro decimal. 0,363 é o coeficiente contra a tabela de 2024; 0,385 é o mesmo
contra a de hoje, e é o que reproduz os euros que a MOB cobrou. Falta confirmar qual é o coeficiente
atual (ver "Perguntas à MOB" no CLAUDE.md).

### 2. 7% a 52% da base não são móveis
Cada cozinha leva ilhargas (`ILM2_250`), ilhargas interiores (`ILI`/`ILS`), vistas, palas (`PALA_250`),
balcões verticais, rodapé (`RLM100`) e puxadores (`MOB338`) — artigos que **não existem na tabela de
preços** (só tem móveis) e que o pipeline ignorava por completo. Peso na base por tipologia:

| Tipo | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 9 | 10 |
|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|
| Remates | 14% | 21% | 16% | 38% | 24% | 36% | 16% | 23% | 24% |

Numa cozinha a direito ronda os 15–24%; numa cozinha em L ou com cantos sobe para 36–38%. Era daí que
vinham os −23…−34% dos tipos 4, 6, 8 e 8.1 — **não de faltarem módulos**: a folha "Montagem" dá a
contagem de móveis da MOB (15/13/13/11/14/12/19/12/11/17) e a app conta tantos ou mais.

Tarifa deduzida (erro < 0,5% em 12 medições), em `config.FinishingTariff` — **A CONFIRMAR**:
`ILM2_250` e `PALA_250` **235,3 €/m²** · `ILI`/`ILS` **212,5 €/m²** · vistas **249 €/m²** ·
`BALCAO VERT` **289 €/m²** · `RLM100` **81,51 € por barra de 2 440 mm** (arredondada para cima) ·
`MOB338` **11,88 €/un**, um por frente.

### 3. O "X por cozinha" é a montagem, não o tampo
A folha **"Montagem"** do Resumo da proposta tem a tabela de preços unitários e as quantidades por
tipologia, e reproduz os 10 valores ao cêntimo (Tipo 1 = 602,80 · Tipo 4 = 530,20 · Tipo 7 = 734,80).
Ver `mob_quote/montagem.py`: 24 €/móvel, 6 €/ilharga-pala-vista, 30 €/balcão, 6 balde, 30 exaustor de
encastre, 7 forno, 7 micro, 12 frigorífico, 12 por máquina de encastre, 12 placa, 12 lava-loiça +
misturadora, 30 rectificação de medidas — **mais 10% de "fator de correcção"**.

### 4. Famílias e alturas que a MOB usa mesmo
`MIL` (não MI) · `MICL` (não MIC) · `MSCDI` (não MSCS) · `MILFS`/`MILDFS` em **todas** as cozinhas
(mesmo quando o desenho não dá código ao lava-loiça) · `MAFMOG21` para a torre forno+micro+gavetas ·
`MIF3B4C` para o inferior de forno · `FI800597_MLL` para as frentes de máquina.

Alturas: colunas a **2280** e inferior de forno a **703**, nenhuma das duas na tabela.

A regra de orçamentação da MOB, nas palavras deles: **"pegar no móvel maior e reduzir, nunca aumentar"**.
Aplicada às colunas, manda usar 2380 e não 2230 — e é a confirmação de que o fator é mesmo único:

| altura usada | rácio ecadpro/tabela nas 6 colunas |
|---|---|
| 2230 (o que a app fazia) | 0,424 a 0,465 (média 0,439) — obrigava a uma sobretaxa inventada |
| **2380** (regra da MOB) | 0,376 a 0,394 (**média 0,386**) — igual aos outros móveis |

Duas linhas da tabela contradizem a progressão da própria família e os ecadpro desmentem-nas
(`pricing.PRECOS_CORRIGIDOS`): `MSCDI640903330` está a 546 € entre um 803 de 1 134 € e um 733 de 886 €;
o valor que reproduz o que a MOB cobrou é 1 199 €.

## Tabela de preços MOB (data/lista_precos_mob.xlsx)
- Colunas: REF (família), **ALT = largura**, **LARG = altura**, PROF, REF, GRUPO (1–16), CAIX (N), REF FINAL, PREÇO.
  28 803 linhas, 19 870 referências finais distintas.
- Famílias: ver `data/descricao_ref_moveis.xlsx` (MIL, MILD, MIG21, MIG02, MILFS, MICL, MS, MSD, MSE, MSMO,
  MSCDI, MAV, MAVD, MAFRI, MAFMO, MAVC, FI/FV frentes, IL ilhargas, etc.).
- **Não tem** ilhargas, palas, vistas, rodapé nem puxadores — ver ponto 2 acima.
- Alturas comerciais: inferiores 733/803; superiores 733/803/903/1003; colunas 1327–2430 (sem 2280).
- Grupo de preços por acabamento: `data/grupos_preco_mob.pdf` (p.17 = Grupo 9 lacado mate, inclui "Bege Mate OPP 6713"
  usado na QUO16519 — confirmado pela MOB). Agravamentos: caixote alumínio +8%, **outro caixote +5%**
  (confirmado), alguns acabamentos +10/15/16/20/45%. Na Almar o +5% não se aplica: o cliente trocou o
  "Branco Hidrófugo 19 mm" por branco normal.
- A tabela que temos pode estar incompleta: a MOB disse que as colunas de 2280 *deviam* lá estar e vai
  verificar se enviou tudo.

## Onde a app ainda não chega
Com tudo o acima, o bloco de cozinhas da Almar fica a **−6,2%** da proposta real (era −14,7%), com
8 das 11 tipologias dentro de ±6%. Sobram os tipos 4 (−16%), 8 (−9%) e 8.1 (−20%): os orçamentos
ecadpro mostram que a MOB lhes acrescentou **palas e balcões verticais** (1 215 € só no Tipo 4) que não
estão nas peças desenhadas do arquiteto. Isso não é derivável do que a app recebe — é decisão de
projeto da MOB, e fica para a revisão humana.
