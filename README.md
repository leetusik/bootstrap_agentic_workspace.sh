# bootstrap_agentic_workspace.sh

[English](README.en.md) | **한국어**

> 코딩 에이전트 — Claude Code, Codex, 어떤 CLI 에이전트든 — 를 규율 있는 팀처럼 일하게 만드는
> 워크스페이스. 일을 **쪼개고**(decompose), 배운 것을 **기억하고**(remember), 넘어가기 전에
> **증명**(prove)하게 합니다.

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)

셸 스크립트 하나가 완전한 워크스페이스를 스캐폴딩합니다: 간결한 에이전트 **계약(contract)**,
파일로 영속되는 **phase → slice 상태 머신**, **버전 관리되는** 문서, 그리고 같은 작업들이
Claude Code와 Codex 양쪽에서 **Agent Skill**로 노출됩니다.

## Quickstart

**요구사항:** `python3 >= 3.8` + POSIX 셸(`sh`/`bash`/`zsh`). `git`은 clone할 때만 필요합니다.

> **python 명령을 직접 칠 일은 없습니다.** 여러분이 직접 실행하는 건 아래 최초 부트스트랩
> 한 번뿐입니다. 이후 `python3 scripts/workflow.py …` 같은 워크플로우 명령은 전부
> **에이전트가** 실행합니다 — 여러분은 자연어로 말만 하면 됩니다.

### 1. 새 프로젝트에 스캐폴딩

```sh
# 스크립트 받기
git clone https://github.com/leetusik/bootstrap_agentic_workspace.sh.git

# 빈 디렉터리에 워크스페이스 생성
mkdir my-project && cd my-project
sh ../bootstrap_agentic_workspace.sh/bootstrap_agentic_workspace.sh . \
  --name "My Project" \
  --summary "이 프로젝트가 무엇인지, 한 문장."
```

원라이너를 선호한다면 (원격 스크립트를 셸에 바로 파이핑하는 게 꺼려지면 먼저 읽어보세요):

```sh
mkdir my-project && cd my-project
curl -fsSL https://raw.githubusercontent.com/leetusik/bootstrap_agentic_workspace.sh/main/bootstrap_agentic_workspace.sh | sh -s -- .
```

### 이미 코드가 있는 저장소라면 — retrofit

일반 부트스트랩은 **빈 디렉터리** 전용입니다. 코드·문서·git 히스토리가 이미 있는 저장소에는
**비파괴 retrofit** 경로를 쓰세요 — 워크스페이스 파일만 추가하고, 이미 있는 것은 건너뛰며,
기존 작업을 절대 덮어쓰지 않습니다:

```sh
sh /path/to/bootstrap_agentic_workspace.sh . --into-existing \
  --name "My Project" --summary "한 문장."
```

에이전트에게 `/retrofit`(Codex는 `$retrofit`)으로 시켜도 됩니다. 상세 절차와 충돌 정책은
**[Retrofit Guide](docs/retrofit-guide.md)** 참고.

### 이미 설치한 워크스페이스 업데이트

머신 부분(엔진·스킬·서브에이전트·계약·템플릿)만 최신으로 덮어쓰고, 여러분의 작업물 —
`works/`의 phase·slice 상태와 `docs/` 전체 — 은 보존합니다:

```sh
sh /path/to/bootstrap_agentic_workspace.sh . --update --dry-run   # 변경 미리보기 — 아무것도 안 씀
sh /path/to/bootstrap_agentic_workspace.sh . --update             # 적용
```

에이전트에게는 `/update-workspace`.

### 2. 에이전트에게 넘기기

터미널이 필요한 건 여기까지입니다. Claude Code나 Codex로 디렉터리를 열고, 말로 지시하세요:

```
/do-next-slice      # Claude Code — slice 하나만 완료하고 멈춤
$do-next-slice      # Codex — 같은 스킬
```

— 또는 그냥 평문으로: *"X를 위한 phase 만들어줘"*, *"끝난 phase들 아카이브해줘"*.
워크플로우 명령·커밋·검증은 전부 에이전트가 타이핑합니다. 여러분(operator)의 일은 판단입니다:
결과를 리뷰하고, `pending` 핸드오프를 풀어주고, 아카이브 시점을 결정하는 것.

## 이게 뭔가요?

코딩 에이전트는 유능하지만 잘 잊습니다. 긴 작업에서 대화가 압축되면 컨텍스트를 잃고, 이미 한
일을 다시 하고, 앞선 결정을 조용히 덮어쓰고, 눈에 띄는 옆길로 샙니다. 이 워크스페이스는
에이전트에게 평소엔 없는 세 가지를 줍니다:

- **라우팅** — "다음에 뭘 하지?"에 대해 기계적으로 검증 가능한 답이 항상 하나 존재
  ([`works/state.json`](works/)과 생성되는 backlog).
- **지속·공유 메모리** — phase별 노트(`phase.md`) + 추가 전용 버전 문서가 각 단계의 학습을
  다음 단계로 넘겨줍니다. 지식이 컨텍스트 압축과 툴 전환을 살아남습니다.
- **리뷰 게이트** — phase review(소스를 건드리지 않는 신선한 컨텍스트에서 실행)가 phase의
  목표 대비 검증을 통과해야 비로소 "done"입니다.

**크로스툴 설계:** 같은 명령과 스킬이 Claude Code와 Codex에서 네이티브로 동작하고, 어디서든
(CI 포함) 통하는 `python3 scripts/workflow.py …` 폴백이 있습니다.

> 이 저장소 자체가 자기 워크플로우로 굴러갑니다. 여기 보이는 [`works/`](works/)와
> [`docs/`](docs/)는 이 시스템의 도그푸딩 흔적 — 이 README도 하나의 phase로 작성됐습니다.

## 어떻게 동작하나

- **Phase** (`P1`, `P2`, …) — 목표를 가진 작업 단위. 새 phase는 `DECOMP`(분해)와 `REVIEW`
  두 slice로만 시작합니다.
- **Slice** (`P1.DECOMP`, `P1.S1`, `P1.REVIEW`, …) — phase 안의 순서 있는 한 걸음. 작업 전에
  `plan.md`를 쓰고, 끝나면 `result.md`를 남깁니다.
- **Deferred job** (`D1`, `D2`, …) — 파킹된 아이디어. 명시적으로 승격하기 전엔 다음 작업
  선택에 영향을 주지 않습니다.

계약은 한 줄로 요약됩니다:

> **Backlog routes. Slice folder explains. Result summarizes. Docs are versioned durable truth.**
> (백로그가 라우팅하고, slice 폴더가 설명하고, result가 요약하고, 문서는 버전 관리되는 지속 진실이다.)

자주 쓰는 스킬 (Claude Code에선 `/slash`, Codex에선 `$skill`):

| 스킬 | 하는 일 |
|---|---|
| `create-phase` | 의도를 확인받은 뒤 phase 생성 (`DECOMP` + `REVIEW`만 시딩) — 분해 전에 멈춤 |
| `do-next-slice` | slice 정확히 하나 완료 후 멈춤 |
| `do-whole-phase` | phase 전체를 리뷰까지 완주 _(Claude Code 전용 — plan mode 필요)_ |
| `review-phase` | phase 리뷰 후 `pass` / `changes_requested` / `blocked` 기록 |
| `retrofit` | 기존 저장소에 워크스페이스 비파괴 도입 |
| `update-workspace` | 설치된 워크스페이스의 머신 부분만 최신으로 — 작업물은 보존 |

총 15개 스킬이 있습니다 — 전체 목록·CLI 명령·옵션 표는 [English README](README.en.md)와
[CLAUDE.md](CLAUDE.md) 참고.

## ⭐ 에이전트와 일하는 6가지 습관

이 워크스페이스가 존재하는 이유이자, 계약([`CLAUDE.md`](CLAUDE.md))이 강제하는 것들:

1. **만들기 전에 쪼갠다.** 모든 phase의 첫 수는 코드가 아니라 분해 slice. 쪼갤 수 없는 일은
   아직 이해하지 못한 일입니다.
2. **에이전트에게 지속·공유 메모리를 준다.** 중요한 컨텍스트를 채팅에만 두지 않습니다 —
   phase 노트와 버전 문서에 남겨, 다음 slice(또는 다음 *툴*)가 이어받게 합니다.
3. **모든 slice가 스스로 증명한다.** `plan.md` 먼저, `result.md`로 마무리, 신선한 컨텍스트의
   리뷰를 통과해야 phase가 닫힙니다. "돌아간다"가 아니라 "리뷰됐고 목표와 일치한다"가 기준.
4. **결정은 버전으로 쌓고, 덮어쓰지 않는다.** 문서는 추가 전용 버전이라 *무엇을 왜 결정했는지*의
   역사가 항상 복원 가능합니다.
5. **딴짓은 파킹하고 쫓지 않는다.** slice 도중의 반짝이는 아이디어는 deferred job으로.
   집중이 의지가 아니라 시스템의 속성이 됩니다.
6. **깨끗한 경계마다 커밋한다.** slice 하나 = 리뷰 가능한 conventional commit 하나. 작고
   읽히는 히스토리가 다음 에이전트(와 미래의 나)를 살립니다.

## 더 알아보기

- 전체 문서 — 옵션 표, CLI 명령 전체, 프로젝트 구조, 스킬 15종: [English README](README.en.md)
- 에이전트 계약 (진실의 원천): [CLAUDE.md](CLAUDE.md) / [AGENTS.md](AGENTS.md)
- 기존 저장소 도입 절차: [Retrofit Guide](docs/retrofit-guide.md)
- 기여하기: 이 저장소는 자기 워크플로우를 도그푸딩합니다 — phase를 열고 slice로 기여하세요.
  방법은 [English README의 Contributing](README.en.md#contributing) 참고.

## License

[Apache License 2.0](LICENSE)
