# bootstrap_agentic_workspace.sh

[English](README.en.md) | **한국어**

> Claude Code를 체계적으로 일하게 만드는 워크스페이스입니다.
> 에이전트가 일을 잘게 나누고, 배운 것을 기록하고, 검증을 통과해야 끝난 것으로 칩니다.

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)

셸 스크립트 하나를 실행하면 에이전트용 워크스페이스가 만들어집니다. 에이전트가 따르는
작업 규칙, 파일로 저장되는 작업 상태, 버전으로 쌓이는 문서가 함께 설치됩니다.
명령은 Claude Code 스킬로 제공되고, 똑같은 동작을 `python3 scripts/workflow.py …`로도
실행할 수 있어 셸이 있는 곳이면(다른 에이전트, 스크립트, CI) 어디서든 같은 워크스페이스를
움직일 수 있습니다.

## 빠른 시작

**준비물:** `python3` 3.8 이상, POSIX 셸(`sh`, `bash`, `zsh`).
`git`은 스크립트를 내려받을 때만 필요합니다.

> **직접 입력하는 명령은 아래 설치 한 번뿐입니다.** 설치가 끝나면
> `python3 scripts/workflow.py …` 같은 워크플로우 명령은 전부 에이전트가 실행합니다.
> 여러분은 말로 지시만 하면 됩니다.

### 1. 새 프로젝트에 설치하기

```sh
# 스크립트 내려받기
git clone https://github.com/leetusik/bootstrap_agentic_workspace.sh.git

# 빈 디렉터리에 워크스페이스 만들기
mkdir my-project && cd my-project
sh ../bootstrap_agentic_workspace.sh/bootstrap_agentic_workspace.sh . \
  --name "My Project" \
  --summary "이 프로젝트가 무엇인지, 한 문장."
```

한 줄로 설치할 수도 있습니다. 원격 스크립트를 셸에 바로 연결하는 방식이 꺼려진다면
스크립트를 먼저 읽어 보세요.

```sh
mkdir my-project && cd my-project
curl -fsSL https://raw.githubusercontent.com/leetusik/bootstrap_agentic_workspace.sh/main/bootstrap_agentic_workspace.sh | sh -s -- .
```

### 이미 코드가 있는 프로젝트라면

위의 기본 설치는 빈 디렉터리 전용입니다. 코드나 git 기록이 이미 있는 저장소에는
`--into-existing` 옵션을 쓰세요. 워크스페이스 파일만 새로 추가하고, 이미 있는 파일은
건너뜁니다. 기존 작업물을 절대 덮어쓰지 않습니다.

```sh
sh /path/to/bootstrap_agentic_workspace.sh . --into-existing \
  --name "My Project" --summary "한 문장."
```

에이전트에게 `/retrofit`이라고 입력해 맡겨도 됩니다.
자세한 절차는 [Retrofit Guide](docs/retrofit-guide.md)에 있습니다.

### 설치한 워크스페이스 업데이트하기

엔진, 스킬, 에이전트 설정 같은 시스템 파일만 최신 버전으로 바꿉니다.
여러분이 만든 작업 기록(`works/`)과 문서(`docs/`)는 그대로 남습니다.

```sh
sh /path/to/bootstrap_agentic_workspace.sh . --update --dry-run   # 바뀔 내용 미리 보기
sh /path/to/bootstrap_agentic_workspace.sh . --update             # 실제 적용
```

에이전트에게는 `/update-workspace`라고 입력하면 됩니다.
업데이트는 기존 `executors.toml`을 보존하지만 생성된 `slice-executor` 에이전트 파일은 최신
기본값으로 바꾸므로, 적용 뒤 `python3 scripts/workflow.py sync-agents`를 실행해 선택한
프리셋과 오버라이드를 다시 반영하세요.

### 2. 에이전트에게 맡기기

터미널이 필요한 일은 여기까지입니다. 이제 Claude Code로 이 디렉터리를 열고,
`/create-phase`로 첫 phase를 만드는 것부터 시작하세요. 전체 흐름은 바로 아래
사용 예시에 있습니다.

## 사용 예시

전형적인 흐름입니다. 전부 에이전트와의 대화로 진행됩니다.

```
/create-phase 결제 모듈에 환불 기능 추가
```

에이전트가 요청을 다듬고, 애매한 부분을 되묻고, 확인을 받은 뒤 phase를 만듭니다.
그리고 멈춥니다. 일을 나누는 것도, 코드를 쓰는 것도 그다음 단계입니다.

실행은 원하는 속도로 진행하세요.

```
/do-next-slice          # slice 하나만 실행하고 멈춤
/do-whole-phase         # phase 끝까지 멈추지 않고 실행 (계획 승인 생략)
/do-whole-phase gate    # slice마다 계획 승인 때만 멈춤
```

자동 실행이 기본입니다. `gate`(slice마다 계획을 승인)와 `plan only`(계획만 쓰고 실행 전에
멈춤)는 명령 뒤에 덧붙이는 선택 사항입니다.

### 시각 디자인 작업: 승인 한 번

제품의 화면 모양을 바꾸는 일이면 `design-cowork` 스킬이 자동으로 작동합니다. **에이전트는
디자인하지 않습니다** — 시각적 결정은 [Claude Design](https://claude.ai/design)과 여러분이
내립니다. Claude Design이 저장소를 직접 읽으므로(Connect GitHub, 또는 로컬 디렉터리 연결)
에이전트는 아무것도 따로 복제하지 않습니다. 검토할 수 있는 카드 세트를 요구하는 `handoff.md`
하나를 쓰되, 카드 경로마다 읽는 순서 번호를 붙여 요구하고(`01-nav.html`, `02-hero.html`, …)
— 그래서 Claude Design의 결과를 여러분이 순서대로 볼 수 있습니다 — 멈춰서 여러분의 디자인
라운드를 기다립니다. **돌아와서 "됐어"라고 말하는 것이 그 한 번의 승인입니다.** 에이전트는
`DesignSync`로 결과를 읽어 번호가 매겨진 카드와 구체성을 확인하고(문제가 있으면 정확히 그
부분만 짚어 다시 멈춥니다), 기록을 그대로 저장소에 반영한 뒤 여러분의 말을 `SIGNOFF.md`에
남깁니다. **목업은 요청할 때만 만듭니다** — phase를 만들 때 `Mockup: requested`로 정하거나
라운드 중에 말로 요청하면, 그 디자인을 프로젝트의 프런트엔드로 만든 실행 가능한 임시 목업으로
띄우고 한 번 더 멈추며, 그때는 그 목업을 직접 열어 승인하는 것이 서명이 됩니다.
(디자인 방식은 `build-after` / `design-only` / `paired` 중에서 여러분이 고릅니다.)
승인은 명시적이어야 하고, 수정은 새 라운드가 되며, 구현은 언제나 별도
slice에서 승인된 디자인을 그대로 따라 진행하고 실제 브라우저로 결과를 확인합니다.

진행 상황은 [`works/backlog.md`](works/backlog.md)에서 확인할 수 있습니다.
아니면 에이전트에게 "지금 어디까지 했어?"라고 물어보세요.

## 왜 필요한가요?

코딩 에이전트는 유능하지만 잘 잊습니다. 작업이 길어지면 대화 앞부분을 잃어버리고,
했던 일을 다시 하고, 앞서 내린 결정을 조용히 뒤집습니다. 이 워크스페이스는 에이전트에게
평소에 없는 세 가지를 줍니다.

- **다음 할 일이 항상 명확합니다.** "다음에 뭘 하지?"의 답이
  [`works/state.json`](works/state.json) 파일에 기록되어 있어서, 어느 세션에서 열어도
  같은 답이 나옵니다.
- **배운 것이 남습니다.** 각 단계에서 알게 된 내용을 노트(`phase.md`)와 버전 문서에
  기록해서, 다음 단계가 이어받습니다. 이 노트는 계속 덧붙이기만 하는 기록이 아니라 정해진
  크기 안에서 매번 다시 쓰는 phase의 **현재 상태**이고, 자세한 기록은 각 slice의
  `result.md`에 남습니다. 대화가 압축돼도, 세션이 바뀌어도 지식이 사라지지 않습니다.
- **검증을 통과해야 끝납니다.** phase는 리뷰를 통과해야 완료 처리됩니다. 리뷰는 깨끗한
  새 컨텍스트에서 실행되어 목표와 결과를 대조합니다. 사용자 눈에 보이는 화면이 바뀐
  phase라면 리뷰가 한 단계 앞에서 멈춥니다. phase가 `pending`이 되고 무엇을 어떻게
  확인하면 되는지 적힌 안내가 나오며, 여러분이 직접 실행 중인 제품을 둘러보고 게이트를
  해제해야(`accept-gate <P> --clear`) 통과가 기록됩니다.

핵심 명령은 Claude Code 스킬로 제공되고, 똑같은 동작을 어디서든(CI 포함) 쓸 수 있는
`python3 scripts/workflow.py …` 명령으로도 실행할 수 있습니다.

> 이 저장소도 이 방식 그대로 개발됩니다. 여기 보이는 [`works/`](works/)와
> [`docs/`](docs/)가 그 기록이고, 이 README도 하나의 phase로 작성됐습니다.

## 핵심 개념

세 가지만 알면 됩니다.

- **phase** (`P1`, `P2`, …) — 하나의 목표를 가진 작업 묶음입니다. 새 phase는 두 개의
  slice로 시작합니다. 일을 나누는 `DECOMP`와 마지막 검증인 `REVIEW`입니다.
- **slice** (`P1.S1`, …) — phase 안의 작은 작업 한 개입니다. 시작 전에 계획(`plan.md`)을
  쓰고, 끝나면 판정 요약으로 시작하는 결과(`result.md`)를 남깁니다.
- **보류 작업** (deferred job, `D1`, …) — 나중에 하기로 미뤄 둔 아이디어입니다. 명시적으로
  꺼내기 전에는 작업 순서에 영향을 주지 않습니다.

규칙 전체는 한 줄로 요약됩니다.

> **Backlog routes. Slice folder explains. Result summarizes. Docs are versioned durable truth.**
> 백로그가 순서를 정하고, slice 폴더가 맥락을 담고, result가 결과를 남기고, 문서는 버전으로 쌓인다.

## 두 종류의 에이전트: 계획과 실행

slice가 실행될 때, 안에서는 에이전트 둘이 역할을 나눠 일합니다.

- **오케스트레이터** — 여러분과 대화하는 메인 에이전트입니다. slice마다 계획(`plan.md`)을
  세우고, 작업 상태를 옮기고, 커밋합니다. `gate`를 고른 경우에만 계획 승인을 기다립니다.
  구현은 직접 하지 않습니다.
- **실행자(`slice-executor`)** — 승인된 계획을 받아 실제 작업을 하는 하위 에이전트입니다.
  매번 깨끗한 새 컨텍스트에서 시작하고, 필요한 파일만 그때그때 읽습니다. 끝나면
  결과(`result.md`)를 쓰고 phase 노트(`phase.md`)를 크기 제한 안에서 갱신한 뒤 판정만
  돌려줍니다. 커밋과 상태 변경은 하지 않습니다.

실행자는 slice의 위험도(`risk`)에 따라 두 티어 중 하나가 선택됩니다. 위험도 표시가 곧
비용 조절 장치입니다 — 한 줄짜리 수정은 싼 모델이, 실제로 코드를 쓰는 일은 좋은 모델이 맡습니다.

| 티어 | `economy` | `flex` | 맡는 일 |
|---|---|---|---|
| `slice-executor-mid` | Sonnet@high | Sonnet@xhigh | `risk`가 정확히 `low`인 slice — 한 줄(또는 몇 줄) 코드 수정, 문서 작업 |
| `slice-executor-high` | Opus@high | Opus@xhigh | 일 나누기(`DECOMP`), 최종 리뷰(`REVIEW`), 그리고 그 외 전부 — 사실상 모든 코드 작성과 여러 파일에 걸친 변경 |

`risk`는 `low`와 `high` 두 값이고 기본값은 `high`입니다. 정확히 `low`일 때만 `mid`로 가므로,
값을 안 줬거나 알아볼 수 없는 값이면 항상 `high`로 떨어집니다 — 안전한 쪽이 기본입니다.

`mid` 티어가 맡은 일이 사실 그 이상이라는 걸 알게 되면 — 진짜 코드 작성이거나, 파일 여러 개에
걸치거나, 계획의 전제가 깨졌거나 — 그 자리에서 멈추고 **에스컬레이션**을 돌려줍니다.
오케스트레이터가 발견 내용을 계획에 반영해 `slice-executor-high`로 다시 맡깁니다.
항상 위로만 올라가고, slice당 최대 한 번입니다.

이렇게 나누는 이유는 두 가지입니다. 오케스트레이터의 컨텍스트가 구현 세부사항으로 채워지지
않아 긴 phase도 끝까지 안정적으로 진행되고, slice마다 새 컨텍스트에서 시작하니 앞 작업의
잔상이 다음 작업을 오염시키지 않습니다. 티어별 모델과 노력 수준은 저장소 루트의
[`executors.toml`](executors.toml)에서 바꿀 수 있습니다 — 에이전트에게 말하면 수정하고
`sync-agents`로 적용해 줍니다. 모델 매핑은 `mode` 프리셋으로 한 번에 바꿀 수 있습니다 —
모드를 고르지 않으면 `economy`(Sonnet@high / Opus@high)이고, `mode = "flex"`는
Sonnet@xhigh / Opus@xhigh를 씁니다. 티어별 `[claude.<tier>]` 표로 항목마다 덮어쓸 수도 있습니다.
모드는 명령 하나로 바꿉니다: `python3 scripts/workflow.py executor-mode flex`(또는 `/executor-mode flex`)가
`mode` 줄을 고치고 에이전트 파일까지 맞춰 주며, 인자 없이 실행하면 지금 모드를 보여 줍니다.

## 문서 통합: docs phase

일반 slice는 일하는 도중에 문서 버전을 만들지 않습니다. 오래 남을 사실을 바꾼 slice는 `phase.md`의
`## Doc impact` 목록에 한 줄 노트를 남기고, 리뷰는 그 목록이 빠짐없는지 확인할 뿐 문서를 통합하지
않습니다. 통과한 phase에는 문서 통합 **빚**이 남고, 빚을 갚기 전까지는 보관(archive)되지 않습니다.
`next`는 `consolidation_owed=<phases>`로 빚을 알려 주고, `python3 scripts/workflow.py docs`는
노트보다 뒤처진 문서를 **STALE**로 표시합니다. 원할 때 "문서 통합해 줘"라고 하거나
`/create-phase 문서 통합`을 입력하면, 에이전트가 `docs-debt`의 작업 목록으로 docs phase를 만들어
문서마다 새 버전을 하나씩 추가하고 `docs-consolidated <P>`로 빚을 갚았다고 기록합니다.
docs phase는 항상 기본 stream(`main`)에서 진행합니다. 자세한 내용은
[English README](README.en.md#durable-docs-a-docs-phase-you-start)에 있습니다.

## 자주 쓰는 명령

Claude Code에서 `/이름`으로 입력합니다.

| 스킬 | 하는 일 |
|---|---|
| `create-phase` | 요청을 확인받은 뒤 phase 생성. 일을 나누기 전에 멈춤 |
| `do-next-slice` | slice 하나만 완료하고 멈춤 |
| `do-whole-phase` | phase를 리뷰까지 끝까지 실행 |
| `review-phase` | phase를 리뷰하고 `pass` / `changes_requested` / `blocked` 기록 |
| `parallel-phase` | 요청했을 때 phase를 자기 worktree에서 실행하고 로컬 merge로 다시 합치기 |
| `executor-mode` | 실행기 모드(`economy` / `flex`) 확인, `/executor-mode flex`처럼 한 번에 전환 |
| `retrofit` | 기존 저장소에 워크스페이스 추가 |
| `update-workspace` | 설치된 워크스페이스의 시스템 파일만 최신으로 교체 |

스킬은 모두 18개입니다. 전체 목록과 설치 옵션은 [English README](README.en.md)에 있고,
CLI 명령 전체는 `python3 scripts/workflow.py --help`로 확인할 수 있습니다.

## phase별 worktree (요청할 때만)

phase는 **기본적으로 지금 있는 checkout(`main`)에서** 진행됩니다. 따로 할 일도, 붙일 옵션도
없습니다. 한 번에 두 phase를 돌리고 싶을 때만 **여러분이 요청**하면, 그 phase가 자기만의 git
worktree로 옮겨갑니다. 요청하는 방법은 둘 중 하나입니다.

- `/do-whole-phase worktree` 또는 `/do-next-slice worktree`처럼 **`worktree`라는 말을 붙여**
  실행하기 (같은 뜻의 다른 표현도 됩니다 — "worktree에서", "병렬로", "자기 branch에서")
- `python3 scripts/workflow.py parallel-start <P>`를 **직접** 실행하기

그러면 에이전트가 `phase/P<N>-<slug>` branch와 `.claude/worktrees/P<N>-<slug>` worktree를 만들고,
**같은 세션 안에서** 그 worktree로 들어가 phase를 끝까지 진행합니다. `main`은 그동안 원래 하던
일을 그대로 계속하고, 각 checkout은 자기 stream의 phase만 봅니다. 한 phase 안의 slice는 여전히
순서대로만 진행됩니다. 에이전트가 먼저 worktree를 만드는 일은 없습니다 — 다른 phase가 진행 중일
때 `next`가 "이 phase는 병렬로 돌릴 수 있습니다"라고 **제안**할 뿐이고, 그 제안을 실행할지는
여러분이 정합니다.

`main`의 작업 트리가 지저분해도 막히지 않습니다. stamp 커밋에는 그 phase 폴더와 다시 생성된
`works/` 파일만 들어가고, 여러분이 커밋하지 않은 수정은 `main`에 그대로 남습니다 — worktree는
그 커밋(최신 커밋)에서 시작합니다. `.claude/worktrees/`는 저장소의 `.git/info/exclude`에
기록되므로 `main`에서 untracked로 보이지 않습니다(`.gitignore`는 건드리지 않습니다).

`main`에 남기려고 따로 할 일은 없습니다 — 그게 기본값입니다. 문서 통합(docs) phase만은
**worktree를 요청하지 마세요**: 문서 버전은 하나의 index에서만 나오기 때문에 `doc-new-version`은
기본 stream에서만 동작합니다. (v42에서 쓰던 `parallel-skip <P>`와 `new-phase --on-main`은 이제
아무것도 하지 않는 no-op으로 남아 있습니다.)

worktree에서 진행한 phase의 리뷰가 통과하면 에이전트가 통합까지 직접 진행합니다:
`parallel-gate <P>`(조용한 시점인지 확인) → worktree에서 나와 `main`으로 → `git merge --no-ff`
(로컬 merge) → `parallel-merge-finish` → 리뷰가 남긴 두 게이트 섹션의 문서 버전 →
`parallel-teardown <P>`. **push와 PR은 여러분이 요청할 때만** 합니다(원격 변형: push → PR →
CI → merge). 나머지 문서 버전 작업은 평소처럼 나중에 docs phase에서 한 번에 처리합니다.
어느 checkout에서든 `parallel-status`로 모든 stream의 진행 상황을 볼 수 있습니다.

자세한 규칙과 절차는 [`parallel-phase`](.claude/skills/parallel-phase/SKILL.md) 스킬(`/parallel-phase`)과
[English README](README.en.md#phase-worktrees-on-request)에 있습니다.

## ⭐ 에이전트와 일하는 6가지 습관

이 워크스페이스를 만든 이유이자, 규칙 문서([`CLAUDE.md`](CLAUDE.md))가 강제하는 것들입니다.

1. **만들기 전에 나눕니다.** 모든 phase의 첫걸음은 코드가 아니라 일을 나누는 것입니다.
   나눌 수 없는 일은 아직 이해하지 못한 일입니다.
2. **기억을 파일로 남깁니다.** 중요한 내용을 채팅에만 두지 않습니다. 노트와 버전 문서에
   기록해서 다음 작업이, 또는 다음 세션이 이어받게 합니다.
3. **모든 작업이 스스로 증명합니다.** 계획을 먼저 쓰고, 결과를 남기고, 새 컨텍스트의
   리뷰를 통과해야 끝입니다. "돌아간다"가 아니라 "검증됐다"가 기준입니다. 사용자 눈에
   보이는 화면이 바뀌었다면 마지막 확인은 여러분 몫입니다. 직접 제품을 열어 보고
   승인해야 phase가 닫힙니다.
4. **결정은 버전으로 쌓습니다.** 문서를 고쳐 쓰지 않고 새 버전을 추가합니다. 무엇을 왜
   결정했는지의 역사가 항상 남습니다.
5. **딴생각은 보류함에 넣습니다.** 작업 중 떠오른 아이디어는 보류 작업으로 적어 두고
   하던 일을 계속합니다. 집중이 의지가 아니라 시스템이 됩니다.
6. **작업 하나마다 커밋 하나.** slice 하나가 끝날 때마다 커밋합니다. 작고 읽기 쉬운
   기록이 다음 에이전트와 미래의 나를 돕습니다.

## 더 알아보기

- 전체 문서 (설치 옵션, CLI 명령 전체, 프로젝트 구조, 스킬 18종): [English README](README.en.md)
- 에이전트 규칙 문서: [CLAUDE.md](CLAUDE.md)
- 기존 저장소에 추가하는 절차: [Retrofit Guide](docs/retrofit-guide.md)
- 기여하기: 이 저장소는 자기 워크플로우로 개발됩니다. phase를 열고 slice 단위로 기여해
  주세요. 방법은 [English README의 Contributing](README.en.md#contributing)에 있습니다.

## License

[Apache License 2.0](LICENSE)
