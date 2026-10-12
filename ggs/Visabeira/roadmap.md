# Roadmap

## Fase 1 – Protótipo (feito)
- [x] Leitura MQT (2 formatos), PDF Revit com keynotes, contagem + preenchimento MQT
- [x] Mapeamento genérico para famílias MOB e preço pela tabela (28 803 refs)
- [x] Excel de proposta com fórmulas + folha de revisão
- [x] Web: upload, processamento em background, revisão editável, download
- [x] Passo de visão com Claude API (**validado contra a API**: −6,4% → −5,0% na Almar)
- [x] Testes de regressão Almar

## Fase 2 – Calibração com a MOB
- [x] Leitor dos orçamentos ecadpro da MOB (`ecadpro.py`) → lista de módulos real de 9 tipologias
- [x] Fator tabela→base **medido** (0,385) em vez de calibrado; famílias reais (MIL/MICL/MSCDI/MILDFS)
- [x] Remates (ilhargas, palas, vistas, rodapé, puxadores) — eram 7–52% da base e não eram contados
- [x] Montagem por cozinha a partir da folha "Montagem" (o antigo "tampo por cozinha")
- [ ] Tarifa oficial dos acabamentos e alturas em falta (2280 colunas, 703 forno) — ver CLAUDE.md
- [ ] Palas e balcões verticais dos tipos 4/8/8.1 (a MOB desenha-os; o projeto do arquiteto não os tem)
- [ ] Tabela de acessórios e eletrodomésticos da MOB (hoje: preços da QUO16519)
- [ ] Regra de tampos (€/m² por material e espessura) — a MOB orçamenta-os à parte

## Fase 3 – Robustez
- [x] Validar passo de visão em Almar e medir custo (~0,10 €/tipologia). Tipo 6 passou a +1% e o
      8.1 a −11%; o tipo 4 continua a −16% (palas/balcões que o desenho do arquiteto não tem)
- [ ] Perceber porque é que a visão piora os tipos 2 e 5 (contagem preliminar a induzir em erro?)
- [x] Extrator DWF/ArchiCAD (legendas em texto + cotas): `w2d.py` (Python puro) + `dwf_extract.py`. Pinhão: +2,6%
- [x] Lavandarias (Pinhão: folha 6.13 com 4 plantas): bloco −11%, Lav 1-2 +0,5%, Lav 4 −1,9%
- [ ] Superiores sem legenda (tipos 8/9) e móveis da Lav 3 que só estão no corte
- [ ] Validar o passo de visão sobre as imagens do DWF
- [ ] Outros gabinetes: PDFs raster (OCR + visão), DWG (ODA File Converter → DXF)
- [ ] Guardar correções do orçamentista como dados de treino/regras (ex.: código→família por gabinete)

## Fase 4 – Produto
- [ ] Autenticação, histórico em base de dados, multiutilizador
- [ ] Exportar no layout exato da MOB (logótipo, texto comercial, condições gerais)
- [ ] Preencher diretamente as colunas de preço do MQT do cliente (sem alterar o texto)
