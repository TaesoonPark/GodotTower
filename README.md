# Kingdom Rush Clone

Godot 4.6 기반의 타워 디펜스 게임

## 설치

Godot 4.6을 설치하세요:
- [Godot Engine 다운로드](https://godotengine.org/download/)

## 실행 방법

```bash
godot4.6 --path /mnt/d/tower /mnt/d/tower/Main.tscn
```

## Cursor MCP(Godot) 설정

이 프로젝트에는 Cursor 프로젝트 전용 MCP 설정 파일이 포함되어 있습니다.

- 설정 파일: `.cursor/mcp.json`
- 서버: `@coding-solo/godot-mcp`
- 목적: 에이전트가 Godot 실행/디버그 출력을 직접 확인하는 루프 구성
- 부트스트랩 스크립트: `scripts/start-godot-mcp.sh`

### 1) GODOT_PATH 확인

부트스트랩 스크립트가 아래 순서로 자동 탐지합니다.

1. `GODOT_PATH` 환경 변수
2. `/Applications/Godot.app/Contents/MacOS/Godot`
3. `~/Applications/Godot.app/Contents/MacOS/Godot`
4. 현재 실행 중인 Godot 프로세스 경로

탐지 실패 시 터미널에서 직접 지정:

```bash
export GODOT_PATH="/your/path/to/Godot.app/Contents/MacOS/Godot"
```

### 2) Cursor에서 MCP 서버 활성화

1. Cursor Settings -> Features -> MCP
2. `godot` 서버가 보이는지 확인
3. 필요하면 Refresh 후 Enabled 상태 확인

### 3) 동작 검증

- MCP 툴 `get_godot_version` 실행
- MCP 툴 `run_project`로 이 프로젝트 실행
- MCP 툴 `get_debug_output`으로 에러/경고 확인

이 3단계가 통과하면, 에이전트가 수정 -> 실행 -> 로그확인까지 직접 반복할 수 있습니다.

## 게임 기능

- **타워 설치**: 왼쪽 클릭으로 타워 설치 (100 Gold)
- **타워 업그레이드**: 업그레이드 버튼 클릭 (75 Gold)
- **타워 판매**: 판매 버튼 클릭
- **적 웨이브**: 무한 웨이브 시스템
- **적 체력바**: 각 적의 체력 표시

## 주요 파일

- `scripts/GameManager.gd` - 게임 메인 로직
- `scripts/Tower.gd` - 타워 공격 로직
- `scripts/Enemy.gd` - 적 이동 및 체력 시스템
- `scenes/` - 게임 장면 파일들

## 플레이 방법

1. 게임 시작 시 타워 설치 모드로 진입
2. 적이 경로를 따라 이동할 때 타워로 공격
3. 적을 처치하여 돈 획득
4. 돈으로 타워 업그레이드 또는 추가 설치
