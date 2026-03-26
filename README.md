# ColonySimPrototype

Godot 4.6 기반 림월드 라이크 콜로니 시뮬레이터 프로토타입입니다.

## 현재 상태

- RTS 입력: 단일 선택/드래그 다중 선택/우클릭 즉시 이동 명령
- 주민 상태: `Health`, `Hunger`, `Rest`, `Mood`
- 작업 시스템: 우선순위 기반 작업 할당(`MoveTo`, `EatStub`, `IdleRecover`, `BuildSite`)
- 건축 시스템: 빌드 모드에서 청사진 배치, 주민이 건설 진행/완공
- UI: 선택 수, 욕구 상태, 우선순위 조정, 빌드 모드 토글

상세 정리와 TODO는 `docs/STATUS_AND_TODO.md`를 참고하세요.

## 실행

```bash
godot --path .
```

또는 Godot 에디터에서 프로젝트를 열어 실행하세요.

## 기본 해상도

- `1920 x 1080 (FHD)`

## 프로젝트 구조

- `scenes/main` : 메인 진입 씬
- `scenes/world` : 월드/내비게이션/건설 사이트
- `scenes/units` : 주민 유닛
- `scenes/ui` : HUD
- `scripts/core` : 메인/주민/HUD 핵심 로직
- `scripts/systems` : 입력/욕구/작업/건축 시스템
- `scripts/data` + `data` : 커스텀 Resource 스키마와 인스턴스

## MCP 연결

Cursor 외 IDE를 포함한 MCP 공통 설정은 아래 문서 참고:

- `docs/MCP_SETUP.md`
