import Foundation

/// Runs one cancellable area scan and only applies results for the latest request.
@MainActor
final class AreaDetection {
    typealias Detect = @Sendable (ScreenSnapshot, CGRect, Int) async -> CGRect?
    private let detect: Detect
    private var task: Task<Void, Never>?
    private var generation = UUID()
    var isPending: Bool { task != nil }

    init(detect: @escaping Detect = { snapshot, region, tolerance in
        let worker = Task.detached(priority: .userInitiated) {
            snapshot.objectBounds(in: region, tolerance: tolerance, isCancelled: { Task.isCancelled })
        }
        return await withTaskCancellationHandler {
            await worker.value
        } onCancel: {
            worker.cancel()
        }
    }) {
        self.detect = detect
    }

    @discardableResult
    func request(snapshot: ScreenSnapshot, region: CGRect, tolerance: Int,
                 completion: @escaping @MainActor (CGRect?) -> Void) -> Task<Void, Never> {
        cancel()
        let token = generation
        let detect = detect
        let current = Task { [weak self] in
            let result = await detect(snapshot, region, tolerance)
            guard let self, self.generation == token, !Task.isCancelled else { return }
            self.task = nil
            completion(result)
        }
        task = current
        return current
    }

    /// Commands such as copy/pin wait for the current scan, but not a replacement.
    func completionForCurrent() -> Task<Bool, Never> {
        let token = generation
        let current = task
        return Task { [weak self] in
            await current?.value
            return self?.generation == token
        }
    }

    func cancel() {
        generation = UUID()
        task?.cancel()
        task = nil
    }
}
