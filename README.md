# 🏢 Home Lab de Infraestrutura Corporativa

> Simulação de ambiente corporativo completo com Active Directory, PFSense, Zabbix, GLPI e Linux Server — ideal para portfólio em vagas de Infraestrutura, Suporte N2/N3, SysAdmin e Analista de Redes.

![Infrastructure](https://img.shields.io/badge/Infrastructure-Corporate%20Lab-blue)
![Windows Server](https://img.shields.io/badge/Windows%20Server-2022-blue?logo=windows)
![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04-orange?logo=ubuntu)
![PFSense](https://img.shields.io/badge/Firewall-PFSense-darkred)
![Zabbix](https://img.shields.io/badge/Monitoring-Zabbix-red)
![GLPI](https://img.shields.io/badge/ITSM-GLPI-green)
![Docker](https://img.shields.io/badge/Container-Docker-blue?logo=docker)

---

## 🏛️ Empresa Simulada

**TechSolutions LTDA**

| Departamento | Descrição |
|---|---|
| Diretoria | Gestão executiva |
| TI | Infraestrutura e suporte |
| RH | Recursos Humanos |
| Financeiro | Contabilidade e finanças |
| Comercial | Vendas e atendimento |

---

## 🗺️ Arquitetura da Rede

```
                        INTERNET
                            |
                       [ PFSense ]
                       192.168.1.1 (WAN)
                            |
         ┌──────────────────┼──────────────────┐
         │                  │                  │
     VLAN 10            VLAN 20            VLAN 30
  Administração         Servidores          Usuários
 192.168.10.0/24      192.168.20.0/24    192.168.30.0/24
         │                  │
    [Admin TI]     ┌────────┼────────┬────────┐
                   │        │        │        │
                [DC01]  [Zabbix]  [GLPI]  [Linux]
              .20.10    .20.30    .20.40   .20.20
                                              │
                              ┌───────────────┘
                          VLAN 30
                    ┌─────────┴─────────┐
               [Win Client 1]    [Win Client 2]
                  .30.100           .30.101
```

---

## 📋 Fases do Projeto

| Fase | Componente | Repositório | Lab (VMs) |
|---|---|---|---|
| 1 | Active Directory (DC01) | ✅ Docs + scripts + testes | ⏳ A implementar |
| 2 | PFSense Firewall + VPN | ✅ Docs + testes | ⏳ A implementar |
| 3 | Linux Server (Samba + SSH) | ✅ Docs + scripts + testes | ⏳ A implementar |
| 4 | Zabbix Monitoring | ✅ Docs + webhook + testes | 🔄 Docker OK / VMs pendentes |
| 5 | GLPI Help Desk | ✅ Docs + testes | 🔄 Docker OK / LDAP pendente |
| — | Runbooks + diagramas | ✅ Concluído | — |

> **Guia para montar as VMs:** [docs/IMPLEMENTACAO.md](docs/IMPLEMENTACAO.md)

---

## 📁 Estrutura do Repositório

```
home-lab-corporativo/
├── docs/
│   ├── diagramas/          # Diagramas de rede e arquitetura
│   ├── active-directory/   # Guia completo do AD
│   ├── pfsense/            # Configuração do firewall
│   ├── zabbix/             # Setup e templates de monitoramento
│   ├── glpi/               # Configuração do help desk
│   ├── docker/             # Docker Compose e configurações
│   └── imagens/            # Screenshots do ambiente
├── scripts/
│   ├── active-directory/   # PowerShell: OUs, usuarios, grupos, DHCP/DNS
│   ├── linux/              # Shell: Samba, smoke-test
│   ├── backup/             # backup.sh
│   ├── zabbix/             # smoke-test + webhook GLPI
│   ├── glpi/               # smoke-test
│   ├── pfsense/            # smoke-test
│   └── smoke-test.ps1      # atalho na raiz (Docker por padrao)
├── docker/
│   ├── docker-compose.yml
│   └── docker-compose.lab.yml
└── runbook/
    ├── novo-funcionario.md
    └── gestao-incidentes.md
```

---

## 🚀 Quick Start

### Pré-requisitos

- VMware Workstation / VirtualBox / Hyper-V
- Mínimo 16GB RAM no host
- 200GB de espaço em disco
- ISO: Windows Server 2022, Ubuntu Server 22.04

### Ordem de Implementação

```
1. PFSense    → Gateway e segmentação de rede
2. DC01       → Active Directory, DNS, DHCP
3. Linux      → Samba, SSH, Backup
4. Zabbix     → Monitoramento
5. GLPI       → Help Desk
6. Clientes   → Windows 10/11 no domínio
```

---

## 🛠️ Tecnologias Utilizadas

| Categoria | Tecnologia |
|---|---|
| Directory Services | Windows Server 2022, Active Directory, LDAP |
| Policies | Group Policy (GPO) |
| Network Services | DNS, DHCP, VLANs, TCP/IP |
| Firewall/VPN | PFSense, OpenVPN |
| File Services | Samba, SMB |
| Monitoring | Zabbix 6.x |
| ITSM | GLPI 10.x |
| Linux | Ubuntu Server 22.04 |
| Containers | Docker, Docker Compose |
| Scripting | PowerShell, Bash |

---

## 📸 Evidências

As screenshots do ambiente estão em `docs/imagens/` organizadas por fase.

---

## 📖 Documentação Completa

- [Active Directory](docs/active-directory/README.md) · [Testes AD](docs/active-directory/TESTES.md)
- [PFSense](docs/pfsense/README.md) · [Testes PFSense](docs/pfsense/TESTES.md)
- [Linux Server](docs/linux/README.md) · [Testes Linux](docs/linux/TESTES.md)
- [Zabbix](docs/zabbix/README.md) · [Testes Zabbix](docs/zabbix/TESTES.md)
- [GLPI](docs/glpi/README.md) · [Testes GLPI](docs/glpi/TESTES.md)
- [Docker Compose](docs/docker/README.md) · [Testes Docker](docs/docker/TESTES.md)
- [**Guia de Implementação (VMs)**](docs/IMPLEMENTACAO.md)
- [**Diagramas de rede**](docs/diagramas/rede.md)
- [**Guia de Testes — Lab Completo**](docs/TESTES.md)
- [Evidências / screenshots](docs/imagens/README.md)
- [Runbook - Novo Funcionário](runbook/novo-funcionario.md)
- [Runbook - Gestão de Incidentes](runbook/gestao-incidentes.md)
- [Webhook Zabbix → GLPI](scripts/zabbix/README.md)

---

## 👤 Autor

Projeto desenvolvido para demonstração de habilidades em infraestrutura corporativa.

---

*Este projeto simula um ambiente real de TI corporativo para fins de aprendizado e portfólio profissional.*
