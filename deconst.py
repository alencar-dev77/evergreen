import subprocess, re, pathlib, sys, collections

def analyze():
    out = subprocess.run(['flutter','analyze'], capture_output=True, text=True).stdout
    hits = collections.defaultdict(list)
    for line in out.split('\n'):
        if 'invalid_constant' in line or 'non_constant_list_element' in line or 'const_constructor_param_type_mismatch' in line:
            m = re.search(r'• (lib/[^ :]+):(\d+):(\d+) •', line)
            if m: hits[m.group(1)].append((int(m.group(2)), int(m.group(3))))
    return hits

for rodada in range(8):
    hits = analyze()
    if not hits:
        print('sem const inválido'); break
    total = 0
    for f, pos in hits.items():
        p = pathlib.Path(f)
        text = p.read_text()
        lines = text.split('\n')
        # offset absoluto de cada erro, do fim para o começo
        offs = sorted({sum(len(l)+1 for l in lines[:ln-1]) + col-1 for ln,col in pos}, reverse=True)
        for off in offs:
            head = text[:off]
            i = head.rfind('const ')
            while i != -1:
                before = head[:i].rstrip()
                if before.endswith(('=','(','[',',',':','return','=>','{')) or before=='' or head[:i].strip()=='' or head[:i].rstrip().endswith('\n'):
                    break
                i = head.rfind('const ', 0, i)
            if i == -1: continue
            text = text[:i] + text[i+6:]
            total += 1
        p.write_text(text)
    print(f'rodada {rodada}: {total} const removidos em {len(hits)} arquivos')
