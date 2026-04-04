# MCP / Playtest Handoff

## 현재 상태

- 프로젝트 내부 Godot MCP plugin/autoload 의존성 제거 완료
- 외부 MCP 서버 방식으로 통일 완료
- WSL에서 Windows Godot exe 직접 호출 대신 프로젝트 내부 Linux Godot 바이너리 사용
- 헤드리스 플레이테스트 추가 완료
- 실제 GUI 클릭/우클릭/드래그 플레이테스트 추가 완료

## 핵심 파일

- `project.godot`
- `.cursor/mcp.json`
- `mcp/godot-mcp.shared.json`
- `scripts/start-godot-mcp.sh`
- `scripts/resolve-godot-path.sh`
- `scripts/run-playtest.sh`
- `scripts/run-gui-playtest.sh`
- `scripts/gui_playtest.py`
- `scripts/tests/RtsControlSmokeTest.gd`
- `docs/GODOT_MCP_PLAYTEST.md`

## 현재 검증된 실행 명령

헤드리스 기본 스모크:

```bash
bash scripts/run-playtest.sh
```

헤드리스 습격 포함:

```bash
PLAYTEST_INCLUDE_RAID=1 bash scripts/run-playtest.sh
```

실제 GUI 플레이테스트:

```bash
bash scripts/run-gui-playtest.sh
```

환경 재구성:

```bash
bash scripts/setup-playtest-env.sh
```

자동 셀프체크:

```bash
bash scripts/self-check.sh
```

## 실제로 확인된 것

- 헤드리스 스모크 `PASS`
- 헤드리스 습격 포함 스모크 `PASS`
- GUI 플레이테스트 `PASS`
  - 주민 클릭
  - 우클릭 이동
  - 드래그 선택
  - `Campfire` 건축 버튼 클릭
  - 맵 배치
  - 주민 실제 건설 완료

## 구현 메모

- GUI 테스트는 X11 `XTEST` 입력 주입 방식이다.
- HUD 버튼 좌표는 게임이 stdout으로 `GUI_HINT_*` 라인을 출력해 스크립트가 읽는다.
- 건설 완료 판정도 `GUI_EVENT_BUILD_COMPLETED <BuildingId>` 로그로 기다린다.
- GUI 스크린샷은 현재 환경에서 `BadMatch`가 나올 수 있으므로 경고 처리만 한다.

## 다음에 이어서 보기 좋은 작업

- GUI 플레이테스트에 작업대 선택 후 제작 큐 등록 추가
- GUI 플레이테스트에 저장구역/운반 루프 추가
- MCP 서버가 실제 세션에 붙었을 때 `run_project` 기반 검증 루틴까지 문서화
