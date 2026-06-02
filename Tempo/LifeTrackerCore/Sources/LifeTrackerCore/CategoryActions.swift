import Foundation
import SwiftData
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Category mutations that need to propagate to the paired device. Creates/edits
/// already flow through `SessionActions.save` (which broadcasts upserts); only
/// deletes need a dedicated path so the peer removes the record too.
public enum CategoryActions {

    /// Delete a category locally and tell the paired device to do the same.
    /// The local cascade rule removes the category's sessions; the peer mirrors
    /// that cascade when it applies the delete.
    @MainActor
    public static func delete(_ category: LogCategory, in context: ModelContext) {
        let id = category.id
        context.delete(category)
        SessionActions.save(context)   // persists + broadcasts remaining upserts
        #if canImport(WatchConnectivity)
        ConnectivityService.shared.broadcastDeletes(categoryIDs: [id])
        #endif
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
