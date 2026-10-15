# JobsNetworking vNext compatibility notes

- `DefaultJobsAgent` is kept as a public typealias to `JobsDefaultAgent`.
- `APIResponse<T>` is restored for legacy business-envelope decoding.
- `AnySendable` remains available as a deprecated typealias to `JobsValue`.
- `JobsBatch.concurrent` and `JobsBatch.chain` remain available and forward to `JobsWorkflow`.
- `JobsNetworking/AF5` and `JobsNetworking/AF4` are preserved as compatibility subspecs so old Podfiles do not break.
- New projects should prefer `Core + AF5 + Async` (and `PromiseKit` only when truly needed).
