# Foundation Models generation harness

The regular test suite uses an injected Apple generator to verify that every concrete topic and voice reaches the right request, and that all intensity and rewrite choices are preserved. Those checks are deterministic and do not spend time on live model requests.

`AppSessionSmokeTests.testLiveAppleFoundationModelSmokeWhenAvailable` samples real model generation by topic. The opt-in category/voice matrix exercises every concrete topic/voice pair on a device where Apple's on-device model is ready. Guardrail refusals and temporary model failures are acceptable only when generation falls back to the local Bureau engine with an explanatory notice.

Run the live matrix against an Apple Intelligence eligible device:

```sh
DESTINATION="platform=iOS,id=<DEVICE-UDID>" scripts/run_foundation_model_matrix.sh
```

The matrix makes one real generation request for each concrete topic/voice pair. A device that is ineligible, has Apple Intelligence disabled, or has not finished downloading the model reports a skipped test with Apple's availability reason. The `.xcresult` bundle and text log are written under `.build/`.
