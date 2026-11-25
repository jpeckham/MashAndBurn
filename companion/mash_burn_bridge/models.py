"""Strict bridge safety envelope extending the game's common v1 HardwareFrame."""
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

Counter = Annotated[int, Field(strict=True, ge=0, le=2147483647)]
Duty = Annotated[float, Field(ge=0, le=1)]
Valve = Annotated[int, Field(strict=True, ge=0, le=1)]


class HardwareFrame(BaseModel):
    model_config = ConfigDict(strict=True, extra="forbid", allow_inf_nan=False)

    type: Literal["HardwareFrame"]
    version: Literal[1]
    seq: Counter
    tick: Counter
    sent_at_unix_ms: Annotated[int, Field(strict=True, ge=0)]
    step: Literal["MASH_IN", "BOIL", "COOL", "FERMENT", "PACKAGE", "JUDGE", "IDLE"]
    enabled: bool
    safe_state: bool
    heater: Duty
    pump: Duty
    target_temp_c: Annotated[float, Field(ge=0, le=100)]
    pump_duty: Duty
    valve_states: Annotated[list[Valve], Field(min_length=3, max_length=3)]
    hop_drop_hopper: Annotated[int, Field(strict=True, ge=0, le=3)] | None
    sensor_temp_c: Annotated[float, Field(ge=-20, le=130)] | None
    sensor_ok: bool
    connected: bool
    estop: bool
    hazard: Literal["none", "hazard", "fire", "disconnect", "overpressure"]
    fire_phase: Literal["idle", "staging", "resolved"]

    @field_validator("version", mode="before")
    @classmethod
    def integer_version(cls, value):
        if type(value) is not int:
            raise ValueError("Version must be an integer, not a boolean or float")
        return value

    @model_validator(mode="after")
    def consistent_outputs(self):
        if abs(self.pump - self.pump_duty) > 0.000001:
            raise ValueError("Pump aliases disagree")
        if (self.safe_state or not self.enabled) and (
            self.heater or self.pump or any(self.valve_states) or self.hop_drop_hopper is not None
        ):
            raise ValueError("Disarmed telemetry requests active outputs")
        return self
