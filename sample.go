package battle

import (
	"context"
	"time"

	"github.com/google/uuid"
)

type EntityID = uuid.UUID
type ActionID = uuid.UUID
type LogID = uuid.UUID

type CombatantState int

const (
	StateAlive CombatantState = iota
	StateIncapacitated
)

type Log struct {
	ID      LogID
	Action  Action
	Details map[string]interface{}
}

type Action struct {
	ID     ActionID
	Type   string
	Source EntityID
	Target EntityID
	Params map[string]interface{}
}

type Combatant struct {
	ID    EntityID
	State CombatantState
	Stats map[string]interface{}
}

type LogsReceiver interface {
	ReceiveLogs(context.Context, []Log) error
}

type BattleManager struct {
	paused         bool
	turnTicker     *time.Ticker
	logs           []Log
	combatLogic    *CombatLogic
	combatantLogic *CombatantLogic
	logsReceivers  []LogsReceiver
	ctx            context.Context
	cancel         context.CancelFunc
}

func NewBattleManager(ctx context.Context, combatants []*Combatant) (*BattleManager, error) {
	bmCtx, cancel := context.WithCancel(ctx)
	bm := &BattleManager{
		turnTicker:     nil,
		logs:           make([]Log, 0),
		combatLogic:    &CombatLogic{combatants: combatants},
		combatantLogic: &CombatantLogic{combatants: combatants},
		logsReceivers:  nil,
		ctx:            bmCtx,
		cancel:         cancel,
	}
	return bm, nil
}

func (bm *BattleManager) ListLogs() []Log {
	out := make([]Log, len(bm.logs))
	copy(out, bm.logs)
	return out
}

func (bm *BattleManager) Pause() error {
	if bm.turnTicker != nil {
		bm.turnTicker.Stop()
	}
	if bm.cancel != nil {
		bm.cancel()
	}
	bm.paused = true
	return nil
}

func (bm *BattleManager) processTicker() {
	// TODO: resolve actions for the current tick.
}

func (bm *BattleManager) emitNewLogs(ctx context.Context, logs []Log) error {
	for _, r := range bm.logsReceivers {
		if err := r.ReceiveLogs(ctx, logs); err != nil {
			return err
		}
	}
	return nil
}

func (bm *BattleManager) AddLogsReceiver(r LogsReceiver) {
	bm.logsReceivers = append(bm.logsReceivers, r)
}

type BattleField struct {
	combatants []*Combatant
}

func NewBattleField(combatants []*Combatant, bm *BattleManager) (*BattleField, error) {
	bf := &BattleField{
		combatants: combatants,
	}
	if bm != nil {
		bm.AddLogsReceiver(bf)
	}
	return bf, nil
}

func (bf *BattleField) ReceiveLogs(ctx context.Context, logs []Log) error {
	return bf.updateCombatants(logs)
}

func (bf *BattleField) updateCombatants(logs []Log) error {
	// TODO: apply logs to update combatant states.
	return nil
}

type CombatLogic struct {
	combatants []*Combatant
}

func (cl *CombatLogic) ProcessActions(actions []Action) ([]Log, error) {
	// TODO: implement validation, sorting, and log generation
	return nil, nil
}

type CombatantLogic struct {
	combatants []*Combatant
}

func (cpl *CombatantLogic) ProcessCombatants(logs []Log) error {
	// TODO: apply logs to cpl.combatants
	return nil
}
