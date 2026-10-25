###############################################################################
#  ACIDENTES DE TRÂNSITO NAS RODOVIAS BR-381 E BR-262 EM BETIM (MG), 2017–2025
#  Panorama descritivo (capítulo do e-book) e geração dos dados do painel
#
#  Entradas  : dados/acidentesAAAA_por_ocorrencia.xlsx  (PRF – dados abertos)
#              dados/acidentesAAAA_por_pessoa.xlsx      (PRF – dados abertos)
#  Saídas    : resultados/tabelas/  (Tabelas 1 a 3 do capítulo, .csv e .xlsx)
#              resultados/figuras/  (Figuras 1 a 3 do capítulo, .jpg 300 dpi)
#              resultados/numeros_do_texto.txt (todos os valores citados no texto)
#              painel/dados.js      (base do painel interativo, 5.244 acidentes)
#
#  Seções    : 0 Configuração | 1 Importação | 2 Recodificação | 3 Números do texto
#              4 Tabelas | 5 Figuras | 6 Exportação para o painel
###############################################################################

## ------------------------------------------------------------ 0. CONFIGURAÇÃO
pacotes <- c("readxl", "dplyr", "tidyr", "stringr", "stringi", "purrr",
             "ggplot2", "patchwork", "scales", "jsonlite", "openxlsx")
faltam <- pacotes[!vapply(pacotes, requireNamespace, logical(1), quietly = TRUE)]
if (length(faltam) > 0) install.packages(faltam)
suppressPackageStartupMessages(invisible(lapply(pacotes, library, character.only = TRUE)))

DIR_DADOS   <- "dados"
DIR_SAIDA   <- "resultados"
DIR_PAINEL  <- "painel"
ANOS        <- 2017:2025
for (d in file.path(DIR_SAIDA, c("tabelas", "figuras"))) dir.create(d, recursive = TRUE, showWarnings = FALSE)
dir.create(DIR_PAINEL, showWarnings = FALSE)

# Limites aproximados do município de Betim para validar coordenadas
LAT_LIM <- c(-20.25, -19.80)
LON_LIM <- c(-44.45, -43.95)

br_num <- function(x, d = 1) formatC(x, format = "f", digits = d, big.mark = ".", decimal.mark = ",")
br_int <- function(x) formatC(x, format = "d", big.mark = ".", decimal.mark = ",")
pct <- function(a, b, d = 1) br_num(100 * a / b, d)
sem_acento <- function(x) stringr::str_squish(tolower(stringi::stri_trans_general(as.character(x), "Latin-ASCII")))

## ------------------------------------------------------------ 1. IMPORTAÇÃO
ler_hora <- function(h) {
  if (inherits(h, "POSIXt")) return(as.integer(format(h, "%H")))
  if (is.numeric(h)) return(as.integer(floor((h %% 1) * 24 + 1e-9)))
  as.integer(stringr::str_match(as.character(h), "^(\\d{1,2}):")[, 2])
}
ler_data <- function(x) {
  if (inherits(x, c("POSIXt", "Date"))) return(as.Date(x))
  x <- as.character(x)
  as.Date(ifelse(grepl("/", x), as.character(as.Date(x, "%d/%m/%Y")), x))
}
# Coordenadas: parte dos registros perdeu o separador decimal (ex.: -2005039xxx)
corrigir_coord <- function(x, lim) {
  x <- suppressWarnings(as.numeric(gsub(",", ".", as.character(x))))
  for (i in 1:15) { fora <- !is.na(x) & abs(x) > lim; if (!any(fora)) break; x[fora] <- x[fora] / 10 }
  x
}

ocor <- purrr::map_dfr(ANOS, function(a) {
  d <- readxl::read_excel(file.path(DIR_DADOS, sprintf("acidentes%d_por_ocorrencia.xlsx", a)))
  tibble::tibble(
    id = as.numeric(d$id), ano = a, data = ler_data(d$data_inversa), hora = ler_hora(d$horario),
    dia_semana = as.character(d$dia_semana), br = as.numeric(d$br), km = as.numeric(gsub(",", ".", d$km)),
    causa = stringr::str_squish(as.character(d$causa_acidente)),
    tipo = stringr::str_squish(as.character(d$tipo_acidente)),
    classificacao = as.character(d$classificacao_acidente),
    fase_dia = as.character(d$fase_dia), clima = as.character(d$condicao_metereologica),
    tipo_pista = as.character(d$tipo_pista), uso_solo = as.character(d$uso_solo),
    pessoas = as.numeric(d$pessoas), mortos = as.numeric(d$mortos),
    feridos_graves = as.numeric(d$feridos_graves), feridos_leves = as.numeric(d$feridos_leves),
    ilesos = as.numeric(d$ilesos), ignorados = as.numeric(d$ignorados), veiculos = as.numeric(d$veiculos),
    lat = corrigir_coord(d$latitude, 90), lon = corrigir_coord(d$longitude, 180))
})
pess <- purrr::map_dfr(ANOS, function(a) {
  d <- readxl::read_excel(file.path(DIR_DADOS, sprintf("acidentes%d_por_pessoa.xlsx", a)), guess_max = 10000)
  tibble::tibble(id = as.numeric(d$id), ano = a, tipo_veiculo = as.character(d$tipo_veiculo),
                 tipo_envolvido = as.character(d$tipo_envolvido), estado_fisico = as.character(d$estado_fisico),
                 idade = suppressWarnings(as.numeric(d$idade)), sexo = as.character(d$sexo))
})
cat(sprintf("Importados: %d acidentes e %d registros de pessoas (%d–%d)\n", nrow(ocor), nrow(pess), min(ANOS), max(ANOS)))

## ------------------------------------------------------------ 2. RECODIFICAÇÃO
grupo_tipo <- function(x) {
  z <- sem_acento(x)
  dplyr::case_when(
    grepl("traseira|engavetamento", z)                    ~ "Colisão traseira/engavetamento",
    grepl("lateral|transversal", z)                       ~ "Colisão lateral/transversal",
    grepl("frontal", z)                                   ~ "Colisão frontal",
    grepl("atropelamento de (pedestre|pessoa)", z)        ~ "Atropelamento de pedestre",
    grepl("colisao com objeto|colisao com bicicleta", z)  ~ "Colisão com objeto",
    grepl("tombamento|capotamento", z)                    ~ "Tombamento/capotamento",
    grepl("saida de", z)                                  ~ "Saída de pista",
    grepl("queda de", z)                                  ~ "Queda de ocupante",
    TRUE                                                  ~ "Outros")
}
NIV_TIPO <- c("Colisão traseira/engavetamento", "Colisão lateral/transversal", "Tombamento/capotamento",
              "Colisão com objeto", "Saída de pista", "Queda de ocupante", "Atropelamento de pedestre",
              "Colisão frontal", "Outros")
DIAS <- c("Seg", "Ter", "Qua", "Qui", "Sex", "Sáb", "Dom")

ocor <- ocor %>% mutate(
  tipo_g   = factor(grupo_tipo(tipo), levels = NIV_TIPO),
  fatal    = as.integer(mortos > 0),
  ksi      = as.integer(mortos > 0 | feridos_graves > 0),
  dia      = factor(dplyr::case_when(
    grepl("^seg", sem_acento(dia_semana)) ~ "Seg", grepl("^ter", sem_acento(dia_semana)) ~ "Ter",
    grepl("^qua", sem_acento(dia_semana)) ~ "Qua", grepl("^qui", sem_acento(dia_semana)) ~ "Qui",
    grepl("^sex", sem_acento(dia_semana)) ~ "Sex", grepl("^sab", sem_acento(dia_semana)) ~ "Sáb",
    grepl("^dom", sem_acento(dia_semana)) ~ "Dom"), levels = DIAS),
  mes      = as.integer(format(data, "%m")),
  fase     = factor(dplyr::case_when(sem_acento(fase_dia) == "pleno dia" ~ "Pleno dia",
                                     sem_acento(fase_dia) == "plena noite" ~ "Plena noite",
                                     sem_acento(fase_dia) == "amanhecer" ~ "Amanhecer",
                                     sem_acento(fase_dia) == "anoitecer" ~ "Anoitecer"),
                    levels = c("Pleno dia", "Plena noite", "Amanhecer", "Anoitecer")),
  clima_g  = factor(dplyr::case_when(grepl("ceu claro|^sol", sem_acento(clima)) ~ "Céu claro ou sol",
                                     grepl("chuva|garoa", sem_acento(clima)) ~ "Chuva ou garoa",
                                     TRUE ~ "Demais condições"),
                    levels = c("Céu claro ou sol", "Chuva ou garoa", "Demais condições")),
  pista    = factor(tipo_pista, levels = c("Dupla", "Múltipla", "Simples")),
  solo     = factor(ifelse(sem_acento(uso_solo) %in% c("sim", "urbano"), "Urbano", "Rural"), levels = c("Urbano", "Rural")),
  br_lab   = ifelse(br %in% c(381, 262), paste0("BR-", br), "Não informada"),
  # Três eixos de quilometragem (a BR-381 tem dois segmentos de numeração no município)
  eixo     = dplyr::case_when(km <= 10 ~ "BR-381 km 0–10", km >= 340 & km <= 375 ~ "BR-262 km 340–375",
                              km >= 470 & km <= 520 ~ "BR-381 km 470–520", TRUE ~ NA_character_),
  km_seg   = floor(km),
  coord_ok = !is.na(lat) & !is.na(lon) & lat >= LAT_LIM[1] & lat <= LAT_LIM[2] & lon >= LON_LIM[1] & lon <= LON_LIM[2])

# Pessoas: tipo de usuário e gravidade individual
pess <- pess %>% mutate(
  env = sem_acento(tipo_envolvido), est = sem_acento(estado_fisico), vei = sem_acento(tipo_veiculo),
  moto = grepl("^motocicleta|^motoneta|^ciclomotor", vei),
  pesado = grepl("^caminhao|semireboque|^reboque|^onibus|^micro.?onibus|trator", vei),
  leve = grepl("^automovel|^caminhonete|^camioneta|^utilitario", vei),
  bici = grepl("^bicicleta", vei),
  usuario = dplyr::case_when(
    env == "pedestre" ~ "Pedestre", bici ~ "Ciclista",
    moto & env == "condutor" ~ "Motociclista (condutor)", moto & env == "passageiro" ~ "Motociclista (garupa)",
    pesado ~ "Ocupante de veículo pesado/ônibus", leve ~ "Ocupante de automóvel/utilitário",
    TRUE ~ "Outros/não identificado"),
  conhecido = est %in% c("lesoes graves", "ferido grave", "obito", "morto", "ileso", "lesoes leves", "ferido leve"),
  ksi_p = est %in% c("lesoes graves", "ferido grave", "obito", "morto"),
  obito_p = est %in% c("obito", "morto"),
  idade = ifelse(idade > 0 & idade <= 100, idade, NA))
pess_val <- pess %>% filter(is.na(env) | env != "testemunha", conhecido)

# Envolvimento de motocicletas e de veículos pesados por acidente
envolv <- pess %>% filter(is.na(env) | env != "testemunha") %>% group_by(id) %>%
  summarise(com_moto = any(moto), com_pesado = any(pesado), .groups = "drop")
ocor <- ocor %>% left_join(envolv, by = "id") %>%
  mutate(across(c(com_moto, com_pesado), ~ tidyr::replace_na(.x, FALSE)))

## ------------------------------------------------------------ 3. NÚMEROS DO TEXTO
N <- nrow(ocor); M <- sum(ocor$mortos)
anual <- ocor %>% group_by(ano) %>%
  summarise(acidentes = n(), mortos = sum(mortos), feridos_graves = sum(feridos_graves),
            pct_grave_fatal = 100 * mean(ksi), .groups = "drop")
noite <- ocor %>% mutate(periodo = ifelse(fase == "Pleno dia", "dia", "noite")) %>% group_by(periodo) %>%
  summarise(n = n(), m = sum(mortos)) %>% mutate(letal = 100 * m / n)
faixa_h <- ocor %>% mutate(f = cut(hora, c(-1, 5, 11, 17, 23), labels = c("0–5h", "6–11h", "12–17h", "18–23h"))) %>%
  group_by(f) %>% summarise(n = n(), m = sum(mortos), .groups = "drop")
causas <- ocor %>% mutate(c = ifelse(grepl("distancia de seguranca|manter distancia", sem_acento(causa)),
                                     "Não guardar distância de segurança (duas denominações)", causa)) %>%
  count(c, sort = TRUE) %>% mutate(pct = 100 * n / N)
seg <- ocor %>% filter(!is.na(eixo)) %>% count(eixo, km_seg, name = "n") %>% arrange(desc(n))
seg_full <- ocor %>% filter(!is.na(eixo)) %>% group_by(eixo, km_seg) %>%
  summarise(n = n(), mortos = sum(mortos), ksi = sum(ksi), atrop = sum(tipo_g == "Atropelamento de pedestre"), .groups = "drop")
vit <- pess_val %>% filter(ksi_p)
idx_eixo <- ocor %>% filter(!is.na(eixo)) %>% group_by(eixo) %>% summarise(n = n(), mortos = sum(mortos))

linhas_txt <- c(
  "=== NÚMEROS CITADOS NO CAPÍTULO ===",
  sprintf("Acidentes: %s | pessoas envolvidas: %s | veículos: %s", br_int(N), br_int(sum(ocor$pessoas)), br_int(sum(ocor$veiculos))),
  sprintf("Média anual: %s | por dia: %s", br_num(N / length(ANOS), 0), br_num(N / (length(ANOS) * 365.25), 1)),
  sprintf("BR-381: %s%% | BR-262: %s%%", pct(sum(ocor$br == 381, na.rm = TRUE), N), pct(sum(ocor$br == 262, na.rm = TRUE), N)),
  sprintf("Classificação PRF – com feridos: %s%% | sem vítimas: %s%% | fatais: %s%% (%d)",
          pct(sum(ocor$classificacao == "Com Vítimas Feridas"), N), pct(sum(ocor$classificacao == "Sem Vítimas"), N),
          pct(sum(ocor$classificacao == "Com Vítimas Fatais"), N), sum(ocor$classificacao == "Com Vítimas Fatais")),
  sprintf("Mortos no local: %d | feridos graves: %s | feridos leves: %s | estado ignorado: %s",
          M, br_int(sum(ocor$feridos_graves)), br_int(sum(ocor$feridos_leves)), br_int(sum(ocor$ignorados))),
  sprintf("Variação de acidentes 2021→2024: +%s%%", br_num(100 * (anual$acidentes[anual$ano == 2024] / anual$acidentes[anual$ano == 2021] - 1))),
  sprintf("%%  grave/fatal 2017: %s%% | 2025: %s%%", br_num(anual$pct_grave_fatal[1]), br_num(anual$pct_grave_fatal[nrow(anual)])),
  sprintf("Letalidade noite/crepúsculo: %s | pleno dia: %s | razão: %s",
          br_num(noite$letal[noite$periodo == "noite"]), br_num(noite$letal[noite$periodo == "dia"]),
          br_num(noite$letal[noite$periodo == "noite"] / noite$letal[noite$periodo == "dia"])),
  sprintf("18–23h: %s%% dos acidentes e %s%% das mortes",
          pct(faixa_h$n[faixa_h$f == "18–23h"], N), pct(faixa_h$m[faixa_h$f == "18–23h"], M)),
  sprintf("Dias: %s", paste(sprintf("%s %s%%", levels(ocor$dia), pct(as.numeric(table(ocor$dia)), N)), collapse = " | ")),
  sprintf("Mês de maior frequência: %s (%s%%)", c("jan","fev","mar","abr","mai","jun","jul","ago","set","out","nov","dez")[which.max(table(ocor$mes))], pct(max(table(ocor$mes)), N)),
  sprintf("Acidentes com motocicleta: %s%% | entre os graves/fatais: %s%% | entre os fatais: %s%%",
          pct(sum(ocor$com_moto), N), pct(sum(ocor$com_moto & ocor$ksi == 1), sum(ocor$ksi)), pct(sum(ocor$com_moto & ocor$fatal == 1), sum(ocor$fatal))),
  sprintf("Acidentes com veículo pesado: %s%% | entre os fatais: %s%%",
          pct(sum(ocor$com_pesado), N), pct(sum(ocor$com_pesado & ocor$fatal == 1), sum(ocor$fatal))),
  sprintf("Pessoas com estado físico informado (sem testemunhas): %s | óbitos na base por pessoa: %d",
          br_int(nrow(pess_val)), sum(pess_val$obito_p)),
  sprintf("Vítimas graves/fatais: %% masculino %s | idade mediana %s | 18–44 anos %s%%",
          pct(sum(vit$sexo == "Masculino", na.rm = TRUE), sum(!is.na(vit$sexo))), br_num(median(vit$idade, na.rm = TRUE), 0),
          pct(sum(vit$idade >= 18 & vit$idade <= 44, na.rm = TRUE), sum(!is.na(vit$idade)))),
  sprintf("Eixo BR-381 km 470–520: %s%% dos acidentes e %s%% das mortes",
          pct(idx_eixo$n[idx_eixo$eixo == "BR-381 km 470–520"], N), pct(idx_eixo$mortos[idx_eixo$eixo == "BR-381 km 470–520"], M)),
  sprintf("Segmentos de 1 km com registros: %d | 10 maiores: %s%% dos acidentes", nrow(seg), pct(sum(head(seg$n, 10)), sum(seg$n))),
  sprintf("Segmento mais frequente: %s, km %d (%d acidentes; %d com vítima grave/fatal)",
          seg_full$eixo[which.max(seg_full$n)], seg_full$km_seg[which.max(seg_full$n)], max(seg_full$n), seg_full$ksi[which.max(seg_full$n)]),
  "Segmentos com mais mortes:", capture.output(print(head(arrange(seg_full, desc(mortos)), 5))),
  "Principais causas (% dos acidentes):", capture.output(print(head(causas, 8))),
  "Série anual:", capture.output(print(anual)))
writeLines(linhas_txt, file.path(DIR_SAIDA, "numeros_do_texto.txt"))
cat(paste(linhas_txt[1:19], collapse = "\n"), "\n")

## ------------------------------------------------------------ 4. TABELAS
linha_cat <- function(var, rotulo) {
  ocor %>% group_by(Categoria = .data[[var]]) %>%
    summarise(Acidentes = n(), Mortos = sum(mortos), .groups = "drop") %>%
    mutate(Característica = rotulo, `%` = 100 * Acidentes / N, `Mortos por 100 acidentes` = 100 * Mortos / Acidentes) %>%
    select(Característica, Categoria, Acidentes, `%`, Mortos, `Mortos por 100 acidentes`)
}
tab1 <- bind_rows(linha_cat("fase", "Fase do dia"), linha_cat("clima_g", "Condição meteorológica"),
                  linha_cat("pista", "Tipo de pista"), linha_cat("solo", "Uso do solo"),
                  tibble::tibble(Característica = "Total", Categoria = "", Acidentes = N, `%` = 100, Mortos = M,
                                 `Mortos por 100 acidentes` = 100 * M / N)) %>%
  mutate(across(c(`%`, `Mortos por 100 acidentes`), ~ round(.x, 1)))

tab2 <- ocor %>% group_by(`Tipo de acidente` = tipo_g) %>%
  summarise(Acidentes = n(), `Acidentes fatais` = sum(fatal), Mortos = sum(mortos), ksi = sum(ksi), .groups = "drop") %>%
  arrange(match(`Tipo de acidente`, NIV_TIPO)) %>%
  mutate(`%` = 100 * Acidentes / N, `% dos acidentes fatais` = 100 * `Acidentes fatais` / sum(`Acidentes fatais`),
         `Mortos por 100 acidentes` = 100 * Mortos / Acidentes, `% com vítima grave ou fatal` = 100 * ksi / Acidentes) %>%
  select(-ksi) %>%
  bind_rows(tibble::tibble(`Tipo de acidente` = "Total", Acidentes = N, `Acidentes fatais` = sum(ocor$fatal), Mortos = M,
                           `%` = 100, `% dos acidentes fatais` = 100, `Mortos por 100 acidentes` = 100 * M / N,
                           `% com vítima grave ou fatal` = 100 * mean(ocor$ksi))) %>%
  mutate(across(where(is.double) & !c(Acidentes, `Acidentes fatais`, Mortos), ~ round(.x, 1)))

ordem_usu <- c("Ocupante de automóvel/utilitário", "Motociclista (condutor)", "Ocupante de veículo pesado/ônibus",
               "Motociclista (garupa)", "Pedestre", "Ciclista", "Outros/não identificado")
tab3 <- pess_val %>% group_by(`Tipo de usuário` = usuario) %>%
  summarise(Pessoas = n(), `Feridos graves ou mortos` = sum(ksi_p), Óbitos = sum(obito_p), .groups = "drop") %>%
  arrange(match(`Tipo de usuário`, ordem_usu)) %>%
  mutate(`% feridos graves ou mortos` = 100 * `Feridos graves ou mortos` / Pessoas,
         `% óbitos` = 100 * Óbitos / Pessoas, `% do total de óbitos` = 100 * Óbitos / sum(Óbitos),
         `% das vítimas graves e fatais` = 100 * `Feridos graves ou mortos` / sum(`Feridos graves ou mortos`)) %>%
  mutate(across(starts_with("%"), ~ round(.x, 1)))

tabelas <- list(Tabela1_condicoes = tab1, Tabela2_tipos = tab2, Tabela3_usuarios = tab3,
                Serie_anual = anual, Causas = causas, Segmentos_1km = arrange(seg_full, desc(n)))
wb <- openxlsx::createWorkbook()
for (nm in names(tabelas)) {
  openxlsx::addWorksheet(wb, nm); openxlsx::writeData(wb, nm, tabelas[[nm]])
  write.csv2(tabelas[[nm]], file.path(DIR_SAIDA, "tabelas", paste0(nm, ".csv")), row.names = FALSE, fileEncoding = "UTF-8")
}
openxlsx::saveWorkbook(wb, file.path(DIR_SAIDA, "tabelas", "tabelas_capitulo.xlsx"), overwrite = TRUE)
print(tab2, width = 200); print(tab3, width = 200)

## ------------------------------------------------------------ 5. FIGURAS (300 dpi)
tema <- theme_classic(base_size = 10, base_family = "serif") +
  theme(plot.title = element_text(size = 10, hjust = .5), axis.text.x = element_text(angle = 45, hjust = 1))
salvar <- function(g, nome, h) ggsave(file.path(DIR_SAIDA, "figuras", paste0(nome, ".jpg")), g,
                                      width = 17, height = h, units = "cm", dpi = 300, device = "jpeg", quality = 92)

# Figura 1 – acidentes, mortos e feridos graves por ano
f1a <- ggplot(anual, aes(factor(ano), acidentes)) + geom_col(fill = "#4C72B0") +
  geom_text(aes(label = acidentes), vjust = -.4, size = 2.7, family = "serif") +
  scale_y_continuous(limits = c(0, 800), expand = expansion(0)) + labs(x = NULL, y = NULL, title = "(a) Acidentes registrados") + tema
f1b <- anual %>% select(ano, `Feridos graves` = feridos_graves, Mortos = mortos) %>%
  pivot_longer(-ano) %>%
  ggplot(aes(factor(ano), value, colour = name, shape = name, group = name)) + geom_line() + geom_point(size = 2) +
  scale_colour_manual(values = c("Feridos graves" = "#DD8452", Mortos = "#C44E52"), name = NULL) +
  scale_shape_manual(values = c("Feridos graves" = 16, Mortos = 15), name = NULL) +
  labs(x = NULL, y = NULL, title = "(b) Vítimas graves e fatais") + tema +
  theme(legend.position = c(.25, .9), legend.background = element_blank())
salvar(f1a + f1b, "Figura1", 7)

# Figura 2 – hora do dia x dia da semana
hd <- ocor %>% filter(!is.na(hora), !is.na(dia)) %>% count(dia, hora) %>%
  complete(dia, hora = 0:23, fill = list(n = 0)) %>% mutate(dia = factor(dia, levels = rev(DIAS)))
f2 <- ggplot(hd, aes(hora, dia, fill = n)) + geom_tile() +
  scale_fill_gradient(low = "#FFF5F0", high = "#67000D", name = "Nº de\nacidentes") +
  scale_x_continuous(breaks = 0:23, expand = c(0, 0)) + labs(x = "Hora do dia", y = NULL) + tema +
  theme(axis.text.x = element_text(angle = 0, hjust = .5), legend.title = element_text(size = 8))
salvar(f2, "Figura2", 6.3)

# Figura 3 – acidentes, mortos e atropelamentos por km (BR-381, km 470–520)
e3 <- seg_full %>% filter(eixo == "BR-381 km 470–520") %>%
  complete(km_seg = full_seq(km_seg, 1), fill = list(n = 0, mortos = 0, ksi = 0, atrop = 0))
k <- max(e3$n) / max(c(e3$mortos, e3$atrop))
f3 <- ggplot(e3, aes(km_seg)) + geom_col(aes(y = n, fill = "Acidentes")) +
  geom_line(aes(y = mortos * k, colour = "Mortos")) + geom_point(aes(y = mortos * k, colour = "Mortos"), size = 1) +
  geom_line(aes(y = atrop * k, colour = "Atropelamentos"), linetype = 2) +
  geom_point(aes(y = atrop * k, colour = "Atropelamentos"), shape = 17, size = 1.2) +
  scale_fill_manual(values = c(Acidentes = "#9DB4D3"), name = NULL) +
  scale_colour_manual(values = c(Mortos = "#C44E52", Atropelamentos = "#55A868"), name = NULL) +
  scale_y_continuous("Nº de acidentes", sec.axis = sec_axis(~ . / k, name = "Mortos / atropelamentos")) +
  labs(x = "Quilômetro da BR-381") + tema +
  theme(axis.text.x = element_text(angle = 0, hjust = .5), legend.position = "top", legend.background = element_blank(),
        legend.spacing.y = unit(0, "pt"))
salvar(f3, "Figura3", 7)
cat("Figuras salvas em", file.path(DIR_SAIDA, "figuras"), "\n")

## ------------------------------------------------------------ 6. EXPORTAÇÃO PARA O PAINEL
# Estrutura esperada pelo painel (window.DATA): listas de categorias e linhas compactas
# [lat, lon, ano, causa, tipo, classificação, severidade, id, data, município, BR, km, mortos, graves, leves]
# Coordenadas fora de Betim (mesmo após a correção do separador decimal) vão como null:
# o painel as mantém nos totais, mas fora do mapa, dos polos e dos rankings.
SEVERIDADES <- c("Fatal", "Ferido grave", "Ferido leve", "Sem vítima", "Indeterminada (envolvido ignorado)")
painel <- ocor %>% mutate(
  sev = dplyr::case_when(mortos > 0 ~ 1L, feridos_graves > 0 ~ 2L, feridos_leves > 0 ~ 3L,
                         ignorados > 0 ~ 5L, TRUE ~ 4L),
  tipo_painel = dplyr::recode(tipo, "Atropelamento de Pessoa" = "Atropelamento de Pedestre"))
cats <- function(x) sort(unique(x[!is.na(x)]))
L_CAUSA <- cats(painel$causa); L_TIPO <- cats(painel$tipo_painel); L_CLASSE <- cats(painel$classificacao)
idx0 <- function(x, niveis) match(x, niveis) - 1L
linhas <- purrr::pmap(list(
  ifelse(painel$coord_ok, round(painel$lat, 7), NA), ifelse(painel$coord_ok, round(painel$lon, 7), NA),
  painel$ano, idx0(painel$causa, L_CAUSA), idx0(painel$tipo_painel, L_TIPO), idx0(painel$classificacao, L_CLASSE),
  painel$sev - 1L, painel$id, format(painel$data, "%Y-%m-%d"), 0L,
  ifelse(painel$br %in% c(381, 262), painel$br, NA), round(painel$km, 1),
  painel$mortos, painel$feridos_graves, painel$feridos_leves), function(...) unname(list(...)))
ok <- painel %>% filter(coord_ok)
DATA <- list(
  meta = list(source = sprintf("PRF – dados abertos, %d–%d", min(ANOS), max(ANOS)), sheet = "acidentes por ocorrência",
              total = nrow(painel), mapped = sum(painel$coord_ok), unmapped = sum(!painel$coord_ok),
              center = c(round(median(ok$lat), 6), round(median(ok$lon), 6)),
              bounds = list(c(min(ok$lat), min(ok$lon)), c(max(ok$lat), max(ok$lon))),
              generated = format(Sys.Date())),
  years = ANOS, causes = L_CAUSA, types = L_TIPO, classes = L_CLASSE, severities = SEVERIDADES,
  municipalities = "BETIM", rows = linhas)
js <- paste0("// Gerado por analise_capitulo_e_painel.R em ", Sys.Date(), " – não editar manualmente\nwindow.DATA = ",
             jsonlite::toJSON(DATA, auto_unbox = TRUE, na = "null", null = "null", digits = NA), ";\n")
writeLines(js, file.path(DIR_PAINEL, "dados.js"), useBytes = TRUE)
cat(sprintf("Painel: %d acidentes exportados (%d com coordenada válida, %d fora do mapa) -> %s\n",
            nrow(painel), sum(painel$coord_ok), sum(!painel$coord_ok), file.path(DIR_PAINEL, "dados.js")))
writeLines(capture.output(sessionInfo()), file.path(DIR_SAIDA, "sessionInfo.txt"))
