# bootstrap_agentic_workspace.sh

[English](README.en.md) | **한국어**

> Claude Code, Codex 같은 코딩 에이전트를 체계적으로 일하게 만드는 워크스페이스입니다.
> 에이전트가 일을 잘게 나누고, 배운 것을 기록하고, 검증을 통과해야 끝난 것으로 칩니다.

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)

셸 스크립트 하나를 실행하면 에이전트용 워크스페이스가 만들어집니다. 에이전트가 따르는
작업 규칙, 파일로 저장되는 작업 상태, 버전으로 쌓이는 문서가 함께 설치됩니다.
같은 명령을 Claude Code와 Codex 어디서든 그대로 쓸 수 있습니다.

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

에이전트에게 `/retrofit`(Codex에서는 `$retrofit`)이라고 입력해 맡겨도 됩니다.
자세한 절차는 [Retrofit Guide](docs/retrofit-guide.md)에 있습니다.

### 설치한 워크스페이스 업데이트하기

엔진, 스킬, 에이전트 설정 같은 시스템 파일만 최신 버전으로 바꿉니다.
여러분이 만든 작업 기록(`works/`)과 문서(`docs/`)는 그대로 남습니다.

```sh
sh /path/to/bootstrap_agentic_workspace.sh . --update --dry-run   # 바뀔 내용 미리 보기
sh /path/to/bootstrap_agentic_workspace.sh . --update             # 실제 적용
```

에이전트에게는 `/update-workspace`(Codex에서는 `$update-workspace`)라고 입력하면 됩니다.
업데이트는 기존 `executors.toml`을 보존하지만 생성된 Claude/Codex 에이전트 파일은 최신
기본값으로 바꾸므로, 적용 뒤 `python3 scripts/workflow.py sync-agents`를 실행해 선택한
프리셋과 오버라이드를 다시 반영하세요.

### 2. 에이전트에게 맡기기

터미널이 필요한 일은 여기까지입니다. 이제 Claude Code나 Codex로 이 디렉터리를 열고,
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
/do-whole-phase gate    # Claude Code 전용: slice마다 계획 승인 때만 멈춤
```

Codex에서도 `$do-next-slice`와 `$do-whole-phase`를 모두 쓸 수 있지만 자동 실행만 지원합니다.
Codex에서 `gate`와 `plan only`를 요청하면 어떤 상태나 파일도 바꾸기 전에 거부합니다.

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
  기록해서, 다음 단계가 이어받습니다. 대화가 압축돼도, 도구를 바꿔도 지식이 사라지지
  않습니다.
- **검증을 통과해야 끝납니다.** phase는 리뷰를 통과해야 완료 처리됩니다. 리뷰는 깨끗한
  새 컨텍스트에서 실행되어 목표와 결과를 대조합니다.

같은 핵심 명령과 스킬이 Claude Code와 Codex에 모두 있고, Codex의 실행 스킬은 자동 모드만
지원합니다. 어디서든(CI 포함) 쓸 수 있는 `python3 scripts/workflow.py …` 명령도 있습니다.

> 이 저장소도 이 방식 그대로 개발됩니다. 여기 보이는 [`works/`](works/)와
> [`docs/`](docs/)가 그 기록이고, 이 README도 하나의 phase로 작성됐습니다.

## 핵심 개념

세 가지만 알면 됩니다.

- **phase** (`P1`, `P2`, …) — 하나의 목표를 가진 작업 묶음입니다. 새 phase는 두 개의
  slice로 시작합니다. 일을 나누는 `DECOMP`와 마지막 검증인 `REVIEW`입니다.
- **slice** (`P1.S1`, …) — phase 안의 작은 작업 한 개입니다. 시작 전에 계획(`plan.md`)을
  쓰고, 끝나면 결과(`result.md`)를 남깁니다.
- **보류 작업** (deferred job, `D1`, …) — 나중에 하기로 미뤄 둔 아이디어입니다. 명시적으로
  꺼내기 전에는 작업 순서에 영향을 주지 않습니다.

규칙 전체는 한 줄로 요약됩니다.

> **Backlog routes. Slice folder explains. Result summarizes. Docs are versioned durable truth.**
> 백로그가 순서를 정하고, slice 폴더가 맥락을 담고, result가 결과를 남기고, 문서는 버전으로 쌓인다.

## 두 종류의 에이전트: 계획과 실행

slice가 실행될 때, 안에서는 에이전트 둘이 역할을 나눠 일합니다.

- **오케스트레이터** — 여러분과 대화하는 메인 에이전트입니다. slice마다 계획(`plan.md`)을
  세우고, 작업 상태를 옮기고, 커밋합니다. Claude Code에서 `gate`를 고른 경우에만 계획 승인을
  기다립니다. 구현은 직접 하지 않습니다.
- **실행자(`slice-executor`)** — 승인된 계획을 받아 실제 작업을 하는 하위 에이전트입니다.
  매번 깨끗한 새 컨텍스트에서 시작하고, 끝나면 결과(`result.md`)와 배운 것(`phase.md` 노트)을
  남기고 판정만 돌려줍니다. 커밋과 상태 변경은 하지 않습니다.

실행자는 slice의 위험도(`risk`)에 따라 두 티어 중 하나가 선택됩니다. 위험도 표시가 곧
비용 조절 장치입니다 — 한 줄짜리 수정은 싼 모델이, 실제로 코드를 쓰는 일은 좋은 모델이 맡습니다.

| 티어 | Claude / Codex (`economy`) | Claude / Codex (`flex`) | 맡는 일 |
|---|---|---|---|
| `slice-executor-mid` | Sonnet@high / GPT-5.6 Luna@high | Sonnet@xhigh / GPT-5.6 Terra@high | `risk`가 정확히 `low`인 slice — 한 줄(또는 몇 줄) 코드 수정, 문서 작업 |
| `slice-executor-high` | Opus@high / GPT-5.6 Terra@high | Opus@xhigh / GPT-5.6 Sol@high | 일 나누기(`DECOMP`), 최종 리뷰(`REVIEW`), 그리고 그 외 전부 — 사실상 모든 코드 작성과 여러 파일에 걸친 변경 |

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
모드를 고르지 않으면 `economy`(Claude Sonnet@high / Opus@high, Codex Luna@high / Terra@high)이고,
`mode = "flex"`는 Claude Sonnet@xhigh / Opus@xhigh, Codex Terra@high / Sol@high을 씁니다.

## 자주 쓰는 명령

Claude Code에서는 `/이름`, Codex에서는 `$이름`으로 입력합니다.

| 스킬 | 하는 일 |
|---|---|
| `create-phase` | 요청을 확인받은 뒤 phase 생성. 일을 나누기 전에 멈춤 |
| `do-next-slice` | slice 하나만 완료하고 멈춤 |
| `do-whole-phase` | phase를 리뷰까지 끝까지 실행 (Codex는 자동 모드만 지원) |
| `review-phase` | phase를 리뷰하고 `pass` / `changes_requested` / `blocked` 기록 |
| `parallel-phase` | phase를 별도 branch + worktree에서 병렬로 실행하고 다시 합치기 |
| `retrofit` | 기존 저장소에 워크스페이스 추가 |
| `update-workspace` | 설치된 워크스페이스의 시스템 파일만 최신으로 교체 |

스킬은 모두 17개입니다. 전체 목록과 CLI 명령, 설치 옵션은
[English README](README.en.md)와 [CLAUDE.md](CLAUDE.md)에 있습니다.

## 병렬 phase (옵트인)

기본적으로 phase는 `main`에서 한 번에 하나씩 순서대로 진행됩니다. 지금 진행 중인 phase와
전혀 다른 영역을 건드리는 phase가 있다면, 뒤에서 대기시키는 대신 **병렬 모드**로 옵트인할 수
있습니다. 그 phase만의 branch와 worktree, 그리고 그 안에서 진행되는 별도의 오케스트레이터
세션이 생기고, `main`은 원래 하던 phase를 그대로 계속합니다. 병렬 모드는 phase 단위로만
켤 수 있는 선택 사항이며 기본값이 아닙니다. 한 phase 안의 slice는 여전히 순서대로만
진행됩니다.

워크스페이스는 다른 phase가 진행 중일 때 새 phase를 만들거나, 대기 중인 phase를 실행하려
할 때 병렬 모드를 **제안만** 합니다. 실제로 옵트인할지는 여러분의 선택입니다.

`parallel-start <P>`로 옵트인하면 phase를 stamp하고 `phase/P<N>-<slug>` branch와 전용
worktree를 만듭니다. 그 worktree에서 새 에이전트 세션을 열어 `/do-whole-phase`나
`/do-next-slice`로 평소처럼 진행하면 됩니다 — 각 checkout은 자기 stream의 phase만 보게
됩니다. 어느 checkout에서든 `parallel-status`로 모든 stream의 진행 상황을 볼 수 있습니다.

병렬로 진행한 phase의 리뷰가 통과하면, 문서 버전 작업은 그 자리에서 하지 않고 나중에 `main`으로
merge된 뒤 한 번에 처리합니다. 에이전트가 `parallel-gate` → PR → CI → merge →
`parallel-merge-finish` → 문서 버전 확정 → `parallel-teardown` 순서로 통합까지 직접
진행합니다.

자세한 절차는 [`parallel-phase`](.claude/skills/parallel-phase/SKILL.md) 스킬
(`/parallel-phase`, Codex에서는 `$parallel-phase`)과
[English README](README.en.md#parallel-phases-opt-in)에 있습니다.

## ⭐ 에이전트와 일하는 6가지 습관

이 워크스페이스를 만든 이유이자, 규칙 문서([`CLAUDE.md`](CLAUDE.md))가 강제하는 것들입니다.

1. **만들기 전에 나눕니다.** 모든 phase의 첫걸음은 코드가 아니라 일을 나누는 것입니다.
   나눌 수 없는 일은 아직 이해하지 못한 일입니다.
2. **기억을 파일로 남깁니다.** 중요한 내용을 채팅에만 두지 않습니다. 노트와 버전 문서에
   기록해서 다음 작업이, 또는 다른 도구가 이어받게 합니다.
3. **모든 작업이 스스로 증명합니다.** 계획을 먼저 쓰고, 결과를 남기고, 새 컨텍스트의
   리뷰를 통과해야 끝입니다. "돌아간다"가 아니라 "검증됐다"가 기준입니다.
4. **결정은 버전으로 쌓습니다.** 문서를 고쳐 쓰지 않고 새 버전을 추가합니다. 무엇을 왜
   결정했는지의 역사가 항상 남습니다.
5. **딴생각은 보류함에 넣습니다.** 작업 중 떠오른 아이디어는 보류 작업으로 적어 두고
   하던 일을 계속합니다. 집중이 의지가 아니라 시스템이 됩니다.
6. **작업 하나마다 커밋 하나.** slice 하나가 끝날 때마다 커밋합니다. 작고 읽기 쉬운
   기록이 다음 에이전트와 미래의 나를 돕습니다.

## 더 알아보기

- 전체 문서 (설치 옵션, CLI 명령 전체, 프로젝트 구조, 스킬 17종): [English README](README.en.md)
- 에이전트 규칙 문서: [CLAUDE.md](CLAUDE.md) / [AGENTS.md](AGENTS.md)
- 기존 저장소에 추가하는 절차: [Retrofit Guide](docs/retrofit-guide.md)
- 기여하기: 이 저장소는 자기 워크플로우로 개발됩니다. phase를 열고 slice 단위로 기여해
  주세요. 방법은 [English README의 Contributing](README.en.md#contributing)에 있습니다.

## License

[Apache License 2.0](LICENSE)
