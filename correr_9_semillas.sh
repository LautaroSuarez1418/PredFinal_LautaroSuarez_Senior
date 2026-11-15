#!/bin/bash
# Paso 1 de 2: corre el notebook de R1 con las 9 semillas primigenias (una corrida completa por semilla).
# Uso: copiar PredFinal_Senior_Suarez_R1.ipynb y este script a ~/buckets/b1/labo2026v/PredFinal y ejecutar:
#   setsid nohup ./correr_9_semillas.sh > /dev/null 2>&1 &
# Cada corrida tarda entre 4 y 18 horas (BO de 70 configuraciones + 2 final train de 30 semillas).
# Si se corta, relanzar: saltea las que ya tienen resultados y la BO retoma desde HT.RDATA.

cd ~/buckets/b1/labo2026v/PredFinal
BASE=PredFinal_Senior_Suarez_R1.ipynb
LOG=~/correr_9_semillas.log
CORRIDAS="20002:102191 20010:315779 20011:631861 20012:667657 20013:932227 20032:350377 20033:777767 20030:104729 20031:207013"

for par in $CORRIDAS; do
  e=${par%%:*}; s=${par##*:}
  python3 - "$BASE" "R1_$e.ipynb" "$e" "$s" <<'PY'
import json, sys, re
src, dst, exp, sem = sys.argv[1:5]
nb = json.load(open(src))
cambios = {"exp": 0, "sem": 0}
for c in nb["cells"]:
    s = c["source"] if isinstance(c["source"], str) else "".join(c["source"])
    if re.search(r"PARAM\$experimento <- \d+", s):
        s = re.sub(r"PARAM\$experimento <- \d+", "PARAM$experimento <- " + exp, s, count=1); cambios["exp"] += 1
    if re.search(r"PARAM\$semilla_primigenia <- \d+", s):
        s = re.sub(r"PARAM\$semilla_primigenia <- \d+", "PARAM$semilla_primigenia <- " + sem, s, count=1); cambios["sem"] += 1
    s = re.sub(r"PARAM\$kaggle\$subir\s*<- TRUE", "PARAM$kaggle$subir  <- FALSE", s)
    c["source"] = s
    if c["cell_type"] == "code":
        c["outputs"] = []; c["execution_count"] = None
json.dump(nb, open(dst, "w"), ensure_ascii=False, indent=1)
if not all(v == 1 for v in cambios.values()):
    sys.exit("ERROR en " + dst + ": " + str(cambios))
PY
  [ $? -ne 0 ] && { echo "$(date '+%F %H:%M') ERROR creando R1_$e.ipynb" >> $LOG; exit 1; }
done

for par in $CORRIDAS; do
  e=${par%%:*}
  if [ -f ~/buckets/b1/exp/WF$e/prediccion_entrega.txt ]; then echo "$(date '+%F %H:%M') WF$e ya terminada, salteo" >> $LOG; continue; fi
  echo "$(date '+%F %H:%M') INICIO WF$e" >> $LOG
  jupyter nbconvert --to notebook --execute --inplace --ExecutePreprocessor.timeout=-1 R1_$e.ipynb > ~/r1_$e.out 2>&1
  echo "$(date '+%F %H:%M') FIN WF$e (codigo $?)" >> $LOG
done

echo "$(date '+%F %H:%M') INICIO ensemble" >> $LOG
jupyter nbconvert --to notebook --execute --inplace --ExecutePreprocessor.timeout=-1 PredFinal_Senior_Suarez_Ensemble.ipynb > ~/ensemble.out 2>&1
echo "$(date '+%F %H:%M') FIN ensemble (codigo $?). Archivos en ~/buckets/b1/exp/ENS/FINAL" >> $LOG
