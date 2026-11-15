# Predicción final · Labo 1 · Analista Sr · Lautaro Suarez

Competencia Kaggle `labo-1-virtual-2026-analista-sr`. Entrega final: **`ENS_R1x9_u0325_9714.csv`**, con 9.714 envíos en 202109.

**Nombres.** "R" es una corrida del plan de experimentos (R0, R1, R2, R4). **R1** es la variante que ganó y pasó a ser el pipeline definitivo. **R1x9** es el modelo entregado: el ensemble de 9 corridas de R1 con distintas semillas primigenias.

## Archivos

| Archivo | Qué hace |
|---|---|
| `PredFinal_Senior_Suarez_R1.ipynb` | Pipeline completo de **una** corrida de R1. Graba `prediccion_local.txt` (202107) y `prediccion_entrega.txt` (202109) en `exp/WF<experimento>/`. Es el codigo "base", sin salidas y con la subida a Kaggle desactivada. |
| `correr_9_semillas.sh` | **Paso 1.** Crea una copia del notebook R1 por semilla primigenia (cambia solo `PARAM$experimento` y `PARAM$semilla_primigenia`), las corre en cadena y al final corre el ensemble. |
| `PredFinal_Senior_Suarez_Ensemble.ipynb` | **Paso 2.** Promedia las probabilidades de las 9 corridas, controla la ganancia en 202107 y escribe el archivo de entrega. |

## Archivo entregado

**`entrega/ENS_R1x9_u0325_9714.csv`** es el archivo que se subió a Kaggle y quedó marcado como entrega final.

| Columna | Contenido |
|---|---|
| `numero_de_cliente` | Los 165.076 clientes de 202109 |
| `Predicted` | `1` = se le envía el estímulo; `0` = no se le envía |

- **9.714 clientes con `Predicted = 1`:** son los que tienen probabilidad promedio de BAJA+2 mayor a 0,0325 en el ensemble R1x9.

## Modelo final

**Ensemble R1x9.** Para cada cliente, se promedian con el mismo peso las probabilidades de 9 corridas completas de R1, cada una con una semilla primigenia distinta. Dentro de cada corrida:

- **Optimización bayesiana:** prueba **70 combinaciones de hiperparámetros** (20 al azar para arrancar y 50 elegidas por la BO). Para evaluar cada combinación entrena 20 modelos iguales con distintas semillas, promedia sus predicciones y se queda con la combinación cuyo promedio mejor separa a los clientes que se van (mayor AUC). Así elige hiperparámetros que rinden bien en un semillerío, como después se usan en producción, y no los que tuvieron suerte con una sola semilla.
- **Producción:** un **semillerío de 30 semillas** con los hiperparámetros elegidos por la BO. La probabilidad de la corrida es el promedio de esos 30 modelos.

En total son 9 × 30 = **270 modelos LightGBM**. Cada corrida tiene su propia BO y llega a hiperparámetros distintos: promediar BO distintas reduce la dependencia de la semilla mucho más que agregar semillas de producción.

**Corte por umbral de probabilidad.** Se envía a todo cliente con probabilidad promedio mayor a **0,0325**. El umbral se eligió en 202107 (local) y en 202109 da la cantidad de envíos que corresponde a ese mes.

| Umbral | Ganancia local R1x9 (202107) | Envíos 202107 | Envíos 202109 | Archivo |
|---|---|---|---|---|
| **0,0325 (entrega)** | **621,2** | 11.312 | **9.714** | `ENS_R1x9_entrega_u0325_9714.csv` |
| 0,0300 (alternativa) | 619,1 | 11.997 | 10.294 | `ENS_R1x9_alternativa_u0300_10294.csv` |

Las ganancias están divididas por 120.000.

## Cambios respecto del workflow z739 Analista Sr de la cátedra

Los cambios están en tres partes: **variables** (R1), **optimización bayesiana** y **modelo final**. Catastrophe Analysis, Data Drifting, el Random Forest de FE y los canaritos quedan igual que en el z739.

| Qué | Cátedra (z739) | Esta entrega |
|---|---|---|
| Campos clave en el modelo | Usa `numero_de_cliente` y `foto_mes` | Los saca del modelo y del Random Forest de FE (P16) |
| Variables intra-mes | Las del z739 | + 5 nuevas: `mtarjetas_consumo`, `ctarjetas_trx`, `ccanales_trx`, `payroll_sobre_saldo` y `margen_total` (P03) |
| Variables históricas | Lags y deltas de orden 1 y 2 | Lags y deltas de orden 1, 2, 3 y 6, más promedio y ratio contra el promedio de 6 meses (P04) |
| Meses de la Bayesian Optimization | Training 201901–202105 · validación 202107 | Training 201901–202103 · validación 202105 (202107 queda libre para medir la ganancia real) |
| Evaluación de cada punto de la BO | 1 LightGBM, AUC en validación | Semillerío de **20 LightGBM**, AUC del promedio de sus probabilidades |
| Configuraciones de la BO | 20 iniciales + 30 inteligentes = 50 | 20 iniciales + 50 inteligentes = **70** |
| `num_iterations` (rango) | 4 a 1.024 | 8 a 150 |
| `learning_rate` (rango) | 2^-7 a 2^-0,1 (0,008 a 0,93) | 0,1 a 0,9 |
| `num_leaves` (rango) | 4 a 2.048 | 4 a 512 |
| `feature_fraction` (rango) | 0,05 a 0,90 | 0,1 a 0,7 |
| Tamaño de las hojas | Busca `min_sum_hessian_in_leaf` (2^-10 a 2^10); `min_data_in_leaf` fijo en 0 | Busca `min_data_in_leaf` (32 a 16.384); `min_sum_hessian_in_leaf` fijo en 0,001 |
| Final train | Uno: 201901–202107 → 202109 | Dos con los mismos hiperparámetros: local (201901–202105 → 202107, para medir) y entrega (201901–202107 → 202109) |
| Paso de la BO al final train | Hiperparámetros a mano | `trafoValue` + `min_data_in_leaf` escalado por la cantidad de filas |
| Semillas del modelo final | 10 | 30 por corrida |
| Semilla primigenia | 102191 | 9 corridas: 102191, 315779, 631861, 667657, 932227, 350377, 777767, 104729 y 207013 |
| Predicción final | El semillerío de una corrida | Promedio de las 9 corridas: 270 LightGBM |
| Envíos | Corte fijo | Umbral de probabilidad 0,0325 → 9.714 envíos |

**Semillerío dentro de la BO.** Cada configuración de hiperparámetros se evalúa entrenando 20 LightGBM con semillas distintas, promediando sus probabilidades sobre 202105 y calculando el AUC de ese promedio. Así la BO busca hiperparámetros buenos para un semillerío, que es lo que se usa en el modelo final, y no para un único modelo. Las 20 semillas son las mismas en todos los puntos de una corrida: la diferencia de AUC entre dos configuraciones se debe a los hiperparámetros.

**Modelos chicos.** Como cada corrida promedia 30 modelos y la entrega promedia 270, la búsqueda se limitó a modelos de hasta 150 árboles con learning rate alto. Así el semillerío en la BO entra en tiempo.

**Ensemble de 9 corridas.** Cada corrida tiene su propia BO y llega a hiperparámetros distintos. La entrega promedia las 9.

### Resultado de la Bayesian Optimization en cada corrida

Punto ganador de cada BO (de 70 configuraciones), con el AUC del semillerío de 20 en 202105. El resto de los parámetros de LightGBM son los fijos y están en el `PARAM.yml` de cada corrida.

| Corrida | Semilla | `num_iterations` | `num_leaves` | `min_data_in_leaf` | `learning_rate` | `feature_fraction` | AUC semillerío |
|---|---|---|---|---|---|---|---|
| WF20002 | 102191 | 133 | 157 | 2.406 | 0,138 | 0,156 | 0,93961 |
| WF20010 | 315779 | 114 | 290 | 1.740 | 0,150 | 0,191 | 0,93948 |
| WF20011 | 631861 | 150 | 215 | 3.265 | 0,100 | 0,292 | 0,94007 |
| WF20012 | 667657 | 150 | 60 | 3.314 | 0,215 | 0,261 | 0,93962 |
| WF20013 | 932227 | 149 | 230 | 12.149 | 0,221 | 0,546 | 0,93976 |
| WF20032 | 350377 | 80 | 328 | 3.868 | 0,210 | 0,450 | 0,94000 |
| WF20033 | 777767 | 105 | 511 | 4.080 | 0,141 | 0,334 | 0,93951 |
| WF20030 | 104729 | 112 | 130 | 2.848 | 0,138 | 0,243 | 0,93940 |
| WF20031 | 207013 | 48 | 139 | 2.468 | 0,375 | 0,314 | 0,93935 |

- **Las 9 BO llegan a AUC casi iguales** (0,9394 a 0,9401), pero con hiperparámetros muy distintos: de 48 a 150 árboles, de 60 a 511 hojas y `feature_fraction` de 0,16 a 0,55. Por eso promediarlas aporta: son modelos distintos con un rendimiento parecido.
- **En 3 de las 9 corridas, `num_iterations` quedó en el borde del rango** (149 o 150), y en una `learning_rate` quedó en el mínimo (0,100). Ampliar esos límites es una mejora posible para una próxima versión.

## Cómo se llegó a este modelo

Todas las corridas usan **corrida doble**: una sola BO (training hasta 202103 con el 20 % de los CONTINUA, testing en 202105) y dos final train con los mismos hiperparámetros:
- **Local:** entrena hasta 202105 y se mide con la clase real de 202107.
- **Entrega:** entrena hasta 202107 y predice 202109 para Kaggle.

Las decisiones se tomaron con la **ganancia local en 202107**. El Public de Kaggle se usó solo como control.

### Punto de partida: z739

- **BO:** 50 configuraciones (20 iniciales y 30 inteligentes), **1 modelo por configuración**, sin semillerío.
- **Producción:** semillerío de **10 semillas**, con un solo final train.

### R0 · Base con los dos semilleríos

**R0 = z739 + estos cambios:**
- **Semillerío en la BO:** cada configuración se evalúa con **20 semillas** (AUC del promedio de las 20 probabilidades) en lugar de 1 modelo.
- **BO más larga:** **70 configuraciones** (20 iniciales y 50 inteligentes) en lugar de 50.
- **Árboles acotados** en el espacio de búsqueda, para que el semillerío en la BO entre en tiempo.
- **Semillerío de producción de 50 semillas** en lugar de 10.
- **Corrida doble:** final train local y final train de entrega.
- **Paso de la BO a producción:** la BO busca algunos hiperparámetros en una escala transformada (por ejemplo, en potencias de 2). trafoValue los convierte a su valor real antes de entrenar los modelos finales. Además, como el final train usa muchas más filas que la BO, min_data_in_leaf (el mínimo de clientes por hoja) se agranda en la misma proporción, para que los árboles finales tengan el mismo tamaño relativo que los que eligió la BO.

Resultado: **603,5** (corte 12.500).

### R0b · Semillerío de producción de 30

**R0b = R0, con el semillerío de producción de 30 semillas** en lugar de 50. Todo lo demás igual, con la misma semilla primigenia.

Resultado: **612,5** (corte 11.500). La diferencia con R0 está dentro del ruido entre semillas (unos 5 a 10 puntos), así que 30 semillas alcanzan. **Desde acá, todas las corridas usan 30 semillas de producción y 20 en la BO.**

### R1 · Variables (pipeline elegido)

**R1 = R0b + tres cambios de variables:**
- **P16:** sin `numero_de_cliente` ni `foto_mes` en el modelo ni en el Random Forest de FE.
- **P03:** 5 variables intra-mes nuevas: `mtarjetas_consumo`, `ctarjetas_trx`, `ccanales_trx`, `payroll_sobre_saldo` y `margen_total`.
- **P04:** lags y deltas de orden 1, 2, 3 y 6, más promedio y ratio contra el promedio de 6 meses.

Resultado: **624,0** (corte 12.000). Es la mayor mejora de todas: +20 sobre R0.

### R2 · Pandemia

**R2 = R1 + dos cambios para los meses de pandemia (202003–202010):**
- **P05:** los lags y deltas que apuntan a esos meses pasan a NA.
- **P07:** esos meses pesan 0,2 al entrenar, en la BO y en los dos final train.

Resultado: **618,5**. No mejora a R1. **Descartado.**

### R1 con más semillas primigenias

**R1 con 5 semillas = R1 sin cambios, corrido con 4 semillas primigenias más,** para saber si el 624 fue mejora real o suerte de la semilla.

- Resultados: 624,0; 613,0; 613,0; 615,5; 623,5. **Media 617,8.** Las cinco superan a R0.
- **Curva de semillas de producción** (corrida WF20013): con 1, 5, 10, 20 y 30 semillas, la ganancia fue 607,5; 627,0; 627,5; 623,0 y 623,5. Después de 10 semillas no se gana nada.

### R4 · Solo lags cortos

**R4 = R1, con lags y deltas solo de orden 1 y 2** (en lugar de 1, 2, 3 y 6). Se corrió con 3 semillas que ya tenían R1, para comparar pareado.

- **Local:** empata con R1 (−1,7 de media).
- **Public:** pierde 16 puntos, en 8 de 9 comparaciones.

**Descartado.**

### Ensemble de corridas de R1

**Ensemble = promedio de las probabilidades de varias corridas de R1** (cada una con su propio semillerío de 30), con el mismo peso para todas.

| Ensemble | Corridas | Ganancia máx. | Media entre 10.000 y 12.000 envíos | Mínimo en esa zona |
|---|---|---|---|---|
| Una corrida sola (promedio) | 1 | 617,8 | — | — |
| R1x5 | 5 | 622,5 | 617,0 | 612,0 |
| R1x7 | 7 | 621,5 | 618,2 | 615,5 |
| **R1x9** | **9** | 621,0 | **618,4** | **616,0** |

Agregar corridas mantiene el máximo y hace la curva más pareja en la zona de corte. Lo que no mejoró:
- **Mezclar con R0, R2 o R4:** resta entre 1 y 8 puntos en la zona de corte.
- **Promediar rankings en lugar de probabilidades:** no mejora.

### Corte por umbral

En lugar de un número fijo de envíos, se usa un umbral de probabilidad, porque 202109 tiene un 13 % menos de clientes por encima de cada umbral que 202107.

- **Zona plana:** la ganancia queda alta entre 0,0275 y 0,0325.
- **Elegido 0,0325:** rinde más que 0,030 en R1x9 (621,2 contra 619,1) y en R1x7 (622,0 contra 617,4), y fue el umbral que más veces ganó en un bootstrap de 500 remuestreos de clientes de 202107.

### Las 9 corridas de R1x9

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
