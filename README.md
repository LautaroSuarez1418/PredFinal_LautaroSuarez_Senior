# Predicción final · Labo 1 · Analista Sr · Lautaro Suarez

Competencia Kaggle `labo-1-virtual-2026-analista-sr`. Entrega final: **`ENS_R1x9_u0325_9714.csv`**, con 9.714 envíos en 202109.

## Archivos

| Archivo | Qué hace |
|---|---|
| `PredFinal_Senior_Suarez_R1.ipynb` | Pipeline completo de **una** corrida: z739 + variables R1 + semillerío en la BO + dos final train de 30 semillas (local y entrega). Graba `prediccion_local.txt` (202107) y `prediccion_entrega.txt` (202109) en `exp/WF<experimento>/`. Es `PredFinal_Senior_Suarez_Version_1.ipynb` sin salidas y con la subida a Kaggle desactivada. |
| `correr_9_semillas.sh` | **Paso 1.** Crea una copia del notebook R1 por semilla primigenia (cambia solo `PARAM$experimento` y `PARAM$semilla_primigenia`), las corre en cadena y al final corre el ensemble. |
| `PredFinal_Senior_Suarez_Ensemble.ipynb` | **Paso 2.** Promedia las probabilidades de las 9 corridas, controla la ganancia en 202107 y escribe el archivo de entrega. |

## Modelo final

**Ensemble R1x9.** Para cada cliente, se promedian con el mismo peso las probabilidades de 9 corridas del notebook R1. Cada corrida usa una semilla primigenia distinta, tiene su propia optimización bayesiana (70 configuraciones, semillerío de 20 en la BO) y promedia 30 semillas de producción. En total son 270 modelos LightGBM. Como cada corrida encuentra hiperparámetros distintos, promediarlas reduce la dependencia de la semilla.

**R1 sobre el z739:**
- Sin `numero_de_cliente` ni `foto_mes` en el modelo ni en el Random Forest de FE (P16).
- 5 variables intra-mes: `mtarjetas_consumo`, `ctarjetas_trx`, `ccanales_trx`, `payroll_sobre_saldo` y `margen_total` (P03).
- Lags y deltas de orden 1, 2, 3 y 6, más promedio y ratio contra el promedio de 6 meses (P04).

**Corte por umbral de probabilidad.** Se envía a todo cliente con probabilidad promedio mayor a **0,0325**. El umbral se eligió en 202107 (local) y en 202109 da la cantidad de envíos que corresponde a ese mes.

| Umbral | Ganancia local R1x9 (202107) | Envíos 202107 | Envíos 202109 | Archivo |
|---|---|---|---|---|
| **0,0325 (entrega)** | **621,2** | 11.312 | **9.714** | `ENS_R1x9_entrega_u0325_9714.csv` |
| 0,0300 (alternativa) | 619,1 | 11.997 | 10.294 | `ENS_R1x9_alternativa_u0300_10294.csv` |

0,0325 rinde más que 0,030 en local, tanto en R1x9 como en R1x7 (622,0 contra 617,4), y fue el umbral que más veces ganó en un bootstrap de 500 remuestreos de clientes de 202107. Ganancias divididas por 120.000.

### Las 9 corridas

| Experimento | Semilla primigenia | Ganancia local máx. |
|---|---|---|
| WF20002 | 102191 | 624,0 |
| WF20010 | 315779 | 613,0 |
| WF20011 | 631861 | 613,0 |
| WF20012 | 667657 | 615,5 |
| WF20013 | 932227 | 623,5 |
| WF20032 | 350377 | 611,5 |
| WF20033 | 777767 | 616,5 |
| WF20030 | 104729 | 625,5 |
| WF20031 | 207013 | 623,0 |
| Media (desvío) | | 618,4 (5,6) |
| **Ensemble R1x9** | | **621,0** (media 618,4 entre 10.000 y 12.000 envíos) |

## Verificación

- **Mismo código en las 9 corridas.** Se comparó el código de los 9 notebooks de las semillas contra `PredFinal_Senior_Suarez_R1.ipynb`, ignorando experimento, semilla y subida a Kaggle. Las únicas diferencias están en el texto del mensaje de Kaggle (`R1` o `R1s`); el modelo es idéntico.
- **Entrega reproducible.** `PredFinal_Senior_Suarez_Ensemble.ipynb`, ejecutado sobre las predicciones de las 9 corridas, genera `ENS_R1x9_entrega_u0325_9714.csv` idéntico byte a byte al archivo entregado en Kaggle.

## Cómo replicar

1. Workflow de la cátedra en Google Cloud, con el dataset `analistasr_competencia_2026.csv.gz` en `~/buckets/b1/datasets/`. VM de 256 GB de RAM: las variables históricas de R1 multiplican las columnas.
2. Copiar los tres archivos a `~/buckets/b1/labo2026v/PredFinal/`.
3. Lanzar:
   ```bash
   cd ~/buckets/b1/labo2026v/PredFinal
   chmod +x correr_9_semillas.sh
   setsid nohup ./correr_9_semillas.sh > /dev/null 2>&1 &
   ```
4. Seguir el avance con `cat ~/correr_9_semillas.log`. Cada corrida tarda entre 4 y 18 horas. Si la VM se corta, se relanza el mismo comando: saltea las corridas terminadas y la BO retoma desde `HT.RDATA`.
5. El archivo de entrega queda en `~/buckets/b1/exp/ENS/FINAL/ENS_R1x9_entrega_u0325_<envios>.csv`.

Si las 9 corridas ya están hechas, alcanza con correr `PredFinal_Senior_Suarez_Ensemble.ipynb`.

La subida automática a Kaggle está desactivada en los dos notebooks (`PARAM$kaggle$subir <- FALSE`).

LightGBM es determinístico con la misma semilla, los mismos datos y la misma cantidad de hilos. En una VM con otra cantidad de vCPU, las probabilidades pueden diferir en los últimos decimales, y los clientes cerca del umbral pueden cambiar en unos pocos.

## Cómo se llegó a este modelo

Todas las decisiones se tomaron con la ganancia local en 202107; el Public de Kaggle se usó solo como control.

| Paso | Resultado | Decisión |
|---|---|---|
| R0 (z739 + semilleríos) y R0b | 603,5 y 612,5 | Base |
| R1 (P16, P03, P04) | 624,0; con 5 semillas, media 617,8, siempre por encima de R0 | Pipeline elegido |
| R2 (lags de pandemia en NA y peso 0,2 a esos meses) | 618,5, no mejora | Descartado |
| R4 (solo lags 1 y 2) | Empata en local; pierde 16 puntos en el Public (8 de 9 comparaciones) | Descartado |
| Ensemble de semillas de R1 | De 1 a 9 BO, la ganancia se estabiliza y la curva queda más pareja en la zona de corte | R1x9 |
| Mezclas con R0, R2 o R4; promedio de rankings | Restan entre 1 y 8 puntos en la zona de corte | Descartado |
| Corte por umbral | 202109 tiene un 13 % menos de clientes por encima del umbral que 202107 | Umbral en vez de corte fijo |
