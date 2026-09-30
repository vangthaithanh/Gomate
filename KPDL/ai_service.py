#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""HTTP API for GoMate cold-start recommendations."""
from typing import List, Optional
from fastapi import FastAPI
from pydantic import BaseModel, Field
from cold_start_adapter import recommend_cold_start

app = FastAPI(title="GoMate AI Recommendation Service", version="v11")

class ColdStartRequest(BaseModel):
    optionCodes: List[str] = Field(default_factory=list, max_length=18)
    destinationKey: Optional[str] = None
    latitude: Optional[float] = Field(default=None, ge=-90, le=90)
    longitude: Optional[float] = Field(default=None, ge=-180, le=180)
    topK: int = Field(default=10, ge=1, le=50)

@app.get("/health")
def health():
    return {"status": "UP", "modelVersion": "v11"}

@app.post("/recommendations/cold-start")
def cold_start(request: ColdStartRequest):
    return recommend_cold_start(request.optionCodes, destination_key=request.destinationKey, latitude=request.latitude, longitude=request.longitude, top_k=request.topK)
